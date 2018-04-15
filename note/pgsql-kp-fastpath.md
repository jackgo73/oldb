# Fast-Path Lock

## fast-path lock是什么？

fast-path是一种为了减少获取、释放某些锁的开销 而设计的特殊的锁机制。这类锁经常使用而且很少发生冲突。使用场景：

1. 必须为弱表锁weak relation locks：AccessShareLock, RowShareLock, RowExclusiveLock。
2. 许多DML操作和少数DDL 操作会创建weak locks。
3. VXID锁。

## 显式锁定？

表级锁模式

- ACCESS SHARE

  只与ACCESS EXCLUSIVE锁模式冲突。SELECT命令在被引用的表上获得一个这种模式的锁。通常，任何只读取表而不修改它的查询都将获得这种锁模式。

- ROW SHARE

  与EXCLUSIVE和ACCESS EXCLUSIVE锁模式冲突。SELECT FOR UPDATE和SELECT FOR SHARE命令在目标表上取得一个这种模式的锁 （加上在被引用但没有选择FOR UPDATE/FOR SHARE的任何其他表上的ACCESS SHARE锁）。

- ROW EXCLUSIVE

  与SHARE、SHARE ROW EXCLUSIVE、EXCLUSIVE和ACCESS EXCLUSIVE锁模式冲突。命令UPDATE、DELETE和INSERT在目标表上取得这种锁模式（加上在任何其他被引用表上的ACCESS SHARE锁）。通常，这种锁模式将被任何修改表中数据的命令取得。

- SHARE UPDATE EXCLUSIVE

  与SHARE UPDATE EXCLUSIVE、SHARE、SHARE ROW EXCLUSIVE、EXCLUSIVE和ACCESS EXCLUSIVE锁模式冲突。这种模式保护一个表不受并发模式改变和VACUUM运行的影响。由VACUUM（ 不 带FULL） 、ANALYZE、CREATE INDEX CONCURRENTLY和ALTER TABLE VALIDATE以及其他ALTER TABLE的变体获得

- SHARE

  与ROW EXCLUSIVE、SHARE UPDATE EXCLUSIVE、SHARE ROW EXCLUSIVE、EXCLUSIVE和ACCESS EXCLUSIVE锁模式冲突。这种模式保护一个表不受并发数据改变的影响。由CREATE INDEX（不带CONCURRENTLY）取得。

- SHARE ROW EXCLUSIVE

  与ROW EXCLUSIVE、SHARE UPDATE EXCLUSIVE、SHARE、SHARE ROW EXCLUSIVE、EXCLUSIVE和ACCESS EXCLUSIVE锁模式冲突。这种模式保护一个表不受并发数据修改所影响，并且是自排他的，这样在一个时刻只能有一个会话持有它。由CREATE TRIGGER和很多 ALTER TABLE的很多形式所获得（见 ALTER TABLE）。

- EXCLUSIVE

  与ROW SHARE、ROW EXCLUSIVE、SHARE UPDATE EXCLUSIVE、SHARE、SHARE ROW EXCLUSIVE、EXCLUSIVE和ACCESS EXCLUSIVE锁 模 式 冲 突 。 这 种 模 式 只 允 许 并 发的ACCESS SHARE锁，即只有来自于表的读操作可以与一个持有该锁模式的事务并行处理。由REFRESH MATERIALIZED VIEW CONCURRENTLY获得。

- ACCESS EXCLUSIVE

  与所有模式的锁冲突（ACCESS SHARE、ROW SHARE、ROW EXCLUSIVE、SHARE UPDATE EXCLUSIVE、SHARE、SHARE ROW EXCLUSIVE、EXCLUSIVE和ACCESS EXCLUSIVE）。这种模式保证持有者是访问该表的唯一事务。由ALTER TABLE、DROP TABLE、TRUNCATE、REINDEX、CLUSTER、VACUUM FULL和REFRESH MATERIALIZED VIEW（ 不 带CONCURRENTLY） 命 令 获 取 。ALTER TABLE的很多形式也在这个层面上获得锁（见ALTER TABLE）。这也是未显式指定模式的LOCK TABLE命令的默认锁模式。 

## 关键数据结构？



```c
/*
 * Count of the number of fast path lock slots we believe to be used.  This
 * might be higher than the real number if another backend has transferred
 * our locks to the primary lock table, but it can never be lower than the
 * real value, since only we can acquire locks on our own behalf.
 */
static int	FastPathLocalUseCount = 0;

/* Macros for manipulating proc->fpLockBits */
#define FAST_PATH_BITS_PER_SLOT			3
#define FAST_PATH_LOCKNUMBER_OFFSET		1

// mask 7 = 0 1 1 1 
#define FAST_PATH_MASK					((1 << FAST_PATH_BITS_PER_SLOT) - 1)
// fpLockBits 右移 3 * n 位置，然后 & 111
#define FAST_PATH_GET_BITS(proc, n) \
	(((proc)->fpLockBits >> (FAST_PATH_BITS_PER_SLOT * n)) & FAST_PATH_MASK)

// n * 3 + l - 1
// 由于 nolock的存在 
// #define NoLock					0
// #define AccessShareLock			1		/* SELECT */
// #define RowShareLock			2		/* SELECT FOR UPDATE/FOR SHARE 
// 所以需要减去FAST_PATH_LOCKNUMBER_OFFSET 1
#define FAST_PATH_BIT_POSITION(n, l) \
	 ((l) - FAST_PATH_LOCKNUMBER_OFFSET + FAST_PATH_BITS_PER_SLOT * (n))

#define FAST_PATH_SET_LOCKMODE(proc, n, l) \
	 (proc)->fpLockBits |= UINT64CONST(1) << FAST_PATH_BIT_POSITION(n, l)
#define FAST_PATH_CLEAR_LOCKMODE(proc, n, l) \
	 (proc)->fpLockBits &= ~(UINT64CONST(1) << FAST_PATH_BIT_POSITION(n, l))
#define FAST_PATH_CHECK_LOCKMODE(proc, n, l) \
	 ((proc)->fpLockBits & (UINT64CONST(1) << FAST_PATH_BIT_POSITION(n, l)))


struct PGPROC
{
    ...
    /* Lock manager data, recording fast-path locks taken by this backend. */
    // 64个二进制位，三个一组
	uint64		fpLockBits;		/* lock modes held for each fast-path slot */
	Oid			fpRelId[16];		/* slots for rel oids */
	bool		fpVXIDLock;		/* are we holding a fast-path VXID lock? */
	LocalTransactionId fpLocalTransactionId;	/* lxid for fast-path VXID */
    ...
}
```

| 二进制位的含义                                               |
| ------------------------------------------------------------ |
| uint64  fpLockBits   :   000    000   000   000   000   ...   000   (使用16*3=48个二进制位) |
| oid        fpRelId[16]  :   oid     oid    oid    oid    oid   ...    oid   (16个oid) |

其中 每一组000中，三个0从左到右为 RowExclusiveLock RowShareLock AccessShareLock



## 判断使用fast-path的条件？

只有1 2 3级锁能使用fast-path

```c
#define EligibleForRelationFastPath(locktag, mode) \
	((locktag)->locktag_lockmethodid == DEFAULT_LOCKMETHOD && \
	(locktag)->locktag_type == LOCKTAG_RELATION && \
	(locktag)->locktag_field1 == MyDatabaseId && \
	MyDatabaseId != InvalidOid && \
	(mode) < ShareUpdateExclusiveLock)
```

## 加锁函数



```c
LockAcquireResult
LockAcquireExtended(const LOCKTAG *locktag,
					LOCKMODE lockmode,
					bool sessionLock,
					bool dontWait,
					bool reportMemoryError)
{
    ...
    /*
	 * Attempt to take lock via fast path, if eligible.  But if we remember
	 * having filled up the fast path array, we don't attempt to make any
	 * further use of it until we release some locks.  It's possible that some
	 * other backend has transferred some of those locks to the shared hash
	 * table, leaving space free, but it's not worth acquiring the LWLock just
	 * to check.  It's also possible that we're acquiring a second or third
	 * lock type on a relation we have already locked using the fast-path, but
	 * for now we don't worry about that case either.
	 */
	if (EligibleForRelationFastPath(locktag, lockmode) &&
		FastPathLocalUseCount < FP_LOCK_SLOTS_PER_BACKEND)
	{
		uint32		fasthashcode = FastPathStrongLockHashPartition(hashcode);
		bool		acquired;

		/*
		 * LWLockAcquire acts as a memory sequencing point, so it's safe to
		 * assume that any strong locker whose increment to
		 * FastPathStrongRelationLocks->counts becomes visible after we test
		 * it has yet to begin to transfer fast-path locks.
		 */
		LWLockAcquire(&MyProc->backendLock, LW_EXCLUSIVE);
		if (FastPathStrongRelationLocks->count[fasthashcode] != 0)
			acquired = false;
		else
			acquired = FastPathGrantRelationLock(locktag->locktag_field2,
												 lockmode);
		LWLockRelease(&MyProc->backendLock);
		if (acquired)
		{
			/*
			 * The locallock might contain stale pointers to some old shared
			 * objects; we MUST reset these to null before considering the
			 * lock to be acquired via fast-path.
			 */
			locallock->lock = NULL;
			locallock->proclock = NULL;
			GrantLockLocal(locallock, owner);
			return LOCKACQUIRE_OK;
		}
	}
    ...
}
```

