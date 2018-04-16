# 两阶段提交

## 什么时候需要使用两阶段提交？

PREPARE TRANSACTION并不是设计为在应用或者交互式 会话中使用。它的目的是允许一个外部事务管理器在多个数据库或者其他事务性 来源之间执行原子的全局事务。除非你在编写一个事务管理器，否则你可能不会 用到PREPARE TRANSACTION。 

注意：让一个事务处于准备好状态太久是不明智的。这将会干扰 VACUUM回收存储的能力，并且在极限情况下可能导致 数据库关闭以阻止事务 ID 回卷。该事务会继续持有它已经持有的锁。该特性的设计用法是只要一个外部事务管理器已经验证其他数据库也准备好了要提交，一个准备好的事务将被正常地提交或者回滚。如果没有建立一个外部事务管理器来跟踪准备好的事务并且确保它们被迅速地结束，最好禁用准备好事务特性（设置 max_prepared_transactions为零）。这将防止意外 地创建准备好事务，不然该事务有可能被忘记并且最终导致问题。 

## 两阶段提交的原理是什么？

二阶段提交的算法思路可以概括为

- 协调者询问参与者是否准备好了提交，并根据所有参与者的反馈情况决定向所有参与者发送commit或者rollback指令（协调者向所有参与者发送相同的指令）。

两阶段是指

- 准备阶段 又称投票阶段。在这一阶段，协调者询问所有参与者是否准备好提交，参与者如果已经准备好提交则回复Prepared，否则回复Non-Prepared。
- 提交阶段 又称执行阶段。协调者如果在上一阶段收到所有参与者回复的Prepared，则在此阶段向所有参与者发送commit指令，所有参与者立即执行commit操作；否则协调者向所有参与者发送rollback指令，参与者立即执行rollback操作。

## 两阶段语法、相关视图是什么？

```sql
PREPARE TRANSACTION transaction_id;
COMMIT PREPARED transaction_id;
ROLLBACK PREPARED;

select * from pg_prepared_xacts;
```

注意：

- `PREPARE TRANSACTION transaction_id`命令后，事务就不再和当前会话关联，因此当前session可继续执行其它事务。
- `COMMIT PREPARED`和`ROLLBACK PREPARED`可在任何会话中执行，而并不要求在提交准备的会话中执行。
- 默认情况下，PostgreSQL并不开启两阶段提交，可以通过在`postgresql.conf`文件中设置`max_prepared_transactions`配置项开启PostgreSQL的两阶段提交。

## PG两阶段状态信息文件的生命周期？

1. PREPARE TRANSACTION时，后台把状态信息只写到WAL中，并将WAL指针存在gxact->prepare_start_lsn中。

2. 如果COMMIT在检查点之前发生了，后端使用prepare_start_lsn 在 WAL中读取数据。

3. 当checkpoint时，状态数据 会 复制到pg_twophase目录中。

4. 如果在检查点之后发生COMMIT，则backend会从文件中读取状态数据。

   **在崩溃恢复过程中，会把从XLOG中取出数据重建文件，耗费大量IO。当时开发的补丁即解决这个问题。**

```c
case TBLOCK_PREPARE:
  PrepareTransaction();
      StartPrepare(gxact);
        //Initializes data structure and inserts the 2PC file header record.
      EndPrepare(gxact);
```

## StartPrepare都记了什么？

```
	uint32		magic;			/* format identifier */
	uint32		total_len;		/* actual file length */
	TransactionId xid;			/* original transaction XID */
	Oid			database;		/* OID of database it was in */
	TimestampTz prepared_at;	/* time of preparation */
	Oid			owner;			/* user running the transaction */
	int32		nsubxacts;		/* number of following subxact XIDs */
	int32		ncommitrels;	/* number of delete-on-commit rels */
	int32		nabortrels;		/* number of delete-on-abort rels */
	int32		ninvalmsgs;		/* number of cache invalidation messages */
	bool		initfileinval;	/* does relcache init file need invalidation? */
	uint16		gidlen;			/* length of the GID - GID follows the header */
```

## EndPrepare都做了什么？

```c
...
XLogInsert(RM_XACT_ID, XLOG_XACT_PREPARE);
...

// make a dummy ProcArray entry for the prepared XID
MarkAsPrepared(gxact);

...

// 同步备机
SyncRepWaitForLSN(gxact->prepare_end_lsn, false);
```

## 什么时候生成两阶段文件？

生成两阶段文件的函数为

```c
RecreateTwoPhaseFile(TransactionId xid, void *content, int len)
```

在 WAL replay和checkpoint creation时才会创建。

在checkpoint creation时

```
CheckPointTwoPhase(XLogRecPtr redo_horizon)
{
    ...
    //在日志中读两阶段状态数据
    XlogReadTwoPhaseData(gxact->prepare_start_lsn, &buf, &len);  
    RecreateTwoPhaseFile(pgxact->xid, buf, len);
    ...
}
```

在WAL replay时

```
void
xact_redo(XLogReaderState *record)
{
    ...
    else if (info == XLOG_XACT_PREPARE)
    {
        RecreateTwoPhaseFile(XLogRecGetXid(record),
						  XLogRecGetData(record), XLogRecGetDataLen(record));
    }
    ...
}
```

## TODO如何优化反复创建删除两阶段状态文件？

文件的创建删除逻辑

```
void
xact_redo(XLogReaderState *record)
{
    ...
    if (info == XLOG_XACT_COMMIT)
    {
        ...
    }
    else
    {
		xact_redo_commit(&parsed, parsed.twophase_xid,
							 record->EndRecPtr, XLogRecGetOrigin(record));
		RemoveTwoPhaseFile(parsed.twophase_xid, false);
    }
    ...
    else if (info == XLOG_XACT_PREPARE)
	{
		RecreateTwoPhaseFile(XLogRecGetXid(record),
						  XLogRecGetData(record), XLogRecGetDataLen(record));
	}
	...
}
```

**优化 方案：在需要创建状态文件时，使用全局事务ID为key，XLogRecGetData(record)为value灌入哈希表，当需要删除时在哈希表中搜索删除对应条目。最终遍历哈希表的剩余条目，将文件创建出来。**

优化方案在社区已经实现了[728bd991c3c4389fb39c45dcb0fe57e4a1dccd71](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=728bd991c3c4389fb39c45dcb0fe57e4a1dccd71)

```c
diff --git a/src/backend/access/transam/xact.c b/src/backend/access/transam/xact.c
index c8751c6..6f614e4 100644 (file)
--- a/src/backend/access/transam/xact.c
+++ b/src/backend/access/transam/xact.c
@@ -5615,7 +5615,9 @@ xact_redo(XLogReaderState *record)
            Assert(TransactionIdIsValid(parsed.twophase_xid));
            xact_redo_commit(&parsed, parsed.twophase_xid,
                             record->EndRecPtr, XLogRecGetOrigin(record));
-           RemoveTwoPhaseFile(parsed.twophase_xid, false);
+
+           /* Delete TwoPhaseState gxact entry and/or 2PC file. */
+           PrepareRedoRemove(parsed.twophase_xid, false);
        }
    }
    else if (info == XLOG_XACT_ABORT || info == XLOG_XACT_ABORT_PREPARED)
@@ -5635,14 +5637,20 @@ xact_redo(XLogReaderState *record)
        {
            Assert(TransactionIdIsValid(parsed.twophase_xid));
            xact_redo_abort(&parsed, parsed.twophase_xid);
-           RemoveTwoPhaseFile(parsed.twophase_xid, false);
+
+           /* Delete TwoPhaseState gxact entry and/or 2PC file. */
+           PrepareRedoRemove(parsed.twophase_xid, false);
        }
    }
    else if (info == XLOG_XACT_PREPARE)
    {
-       /* the record contents are exactly the 2PC file */
-       RecreateTwoPhaseFile(XLogRecGetXid(record),
-                         XLogRecGetData(record), XLogRecGetDataLen(record));
+       /*
+        * Store xid and start/end pointers of the WAL record in
+        * TwoPhaseState gxact entry.
+        */
+       PrepareRedoAdd(XLogRecGetData(record),
+                      record->ReadRecPtr,
+                      record->EndRecPtr);
    }
    else if (info == XLOG_XACT_ASSIGNMENT)
    {
```



## EndPrepare将状态信息丢入XLOG是哪次提交合入的？

[728bd991c3c4389fb39c45dcb0fe57e4a1dccd71](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=728bd991c3c4389fb39c45dcb0fe57e4a1dccd71)

```
Speedup 2PC recovery by skipping two phase state files in normal path

2PC state info held in shmem at PREPARE, then cleaned at COMMIT PREPARED/ABORT PREPARED,
avoiding writing/fsyncing any state information to disk in the normal path, greatly enhancing replay speed.
Prepared transactions that live past one checkpoint redo horizon will be written to disk as now.
Similar conceptually to 978b2f65aa1262eb4ecbf8b3785cb1b9cf4db78e and building upon
the infrastructure created by that commit.

Authors, in equal measure: Stas Kelvich, Nikhil Sontakke and Michael Paquier
Discussion: https://postgr.es/m/CAMGcDxf8Bn9ZPBBJZba9wiyQq-Qk5uqq=VjoMnRnW5s+fKST3w@mail.gmail.com
```

主要改动twophase.c

```
https://git.postgresql.org/gitweb/?p=postgresql.git;a=blobdiff;f=src/backend/access/transam/twophase.c;h=d0e2bbf2916bcedaf5a81cd5cbb8e5c8dc4323ba;hp=83169cccc301179a601b33d7ae0f87145ddd2450;hb=728bd991c3c4389fb39c45dcb0fe57e4a1dccd71;hpb=60a0b2ec8943451186dfa22907f88334d97cb2e0
```



## 分布式事务如何保证原子性？

在分布式系统中，各个节点之间在物理上相互独立，通过网络进行协调。每个独立的节点由于存在事务机制，可以保证其数据操作的ACID特性。但是各节点之间由于相互独立，无法确切地知道其经节点中的事务执行情况，所以多节点之间很难保证ACID，尤其是原子性。

如果要实现分布式系统的原子性，则须保证所有节点的数据写操作，要不全部都执行，要么全部都不执行。但是一个节点在执行本地事务的时候无法知道其它机器的本地事务的执行结果，所以它就不知道本次事务到底应该commit还是 roolback。常规的解决办法是引入一个“协调者”的组件来统一调度所有分布式节点的执行。

## 两阶段提交的几种错误形式？

两阶段提交中的异常主要分为如下三种情况

- 协调者正常，参与方crash

  若参与方在准备阶段crash，则协调者收不到Prepared回复，协调方不会发送commit命令，事务不会真正提交。若参与方在提交阶段提交，当它恢复后可以通过从其它参与方或者协调方获取事务是否应该提交，并作出相应的响应。

- 协调者crash，参与者正常

  可以通过选出新的协调者解决。


- 协调者和参与方都crash

  无法完美解决，尤其是当协调者发送出commit命令后，唯一收到commit命令的参与者也crash，此时其它参与方不能从协调者和已经crash的参与者那儿了解事务提交状态。但如同上一节两阶段提交前提条件所述，两阶段提交的前提条件之一是所有crash的节点最终都会恢复，所以当收到commit的参与方恢复后，其它节点可从它那里获取事务状态并作出相应操作。