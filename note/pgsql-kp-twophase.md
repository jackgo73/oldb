# 两阶段提交

## 什么时候需要使用两阶段提交？

PREPARE TRANSACTION并不是设计为在应用或者交互式 会话中使用。它的目的是允许一个外部事务管理器在多个数据库或者其他事务性 来源之间执行原子的全局事务。除非你在编写一个事务管理器，否则你可能不会 用到PREPARE TRANSACTION。 

注意：让一个事务处于准备好状态太久是不明智的。这将会干扰 VACUUM回收存储的能力，并且在极限情况下可能导致 数据库关闭以阻止事务 ID 回卷。该事务会继续持有它已经持有的锁。该特性的设计用法是只要一个外部事务管理器已经验证其他数据库也准备好了要提交，一个准备好的事务将被正常地提交或者回滚。如果没有建立一个外部事务管理器来跟踪准备好的事务并且确保它们被迅速地结束，最好禁用准备好事务特性（设置 max_prepared_transactions为零）。这将防止意外 地创建准备好事务，不然该事务有可能被忘记并且最终导致问题。 

## 两阶段语法、相关视图是什么？

```sql
PREPARE TRANSACTION transaction_id;
COMMIT PREPARED transaction_id;
ROLLBACK PREPARED;

select * from pg_prepared_xacts;
```

## 状态信息文件的生命周期？

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



##StartPrepare都记了什么？

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

## EndPrepare将状态信息丢入XLOG是哪次提交合入的？

