# Postgresql逻辑备份与恢复实战

> JackGao
>
> Email: jackgo73@outlook.com
>
> Date:  20180419

## pg_dump原理

pg_dump创建的备份在内部是一致的，dump数据pg_dump开始运行时刻的数据库快照，且在pg_dump运行过程中发生的更新将不会被转储。pg_dump工作的时候并不阻塞其他的对数据库的操作。 

```
ConnectDatabase
  | --> PQconnectdbParams
  | --> PQstatus
  | --> PQconnectionUsedPassword
setup_connection
  | --> "SET DATESTYLE = ISO"
        "SET INTERVALSTYLE = POSTGRES"
        "SET extra_float_digits TO 3"
        "SET synchronize_seqscans TO off"
        "SET lock_timeout = 0"
        "SET idle_in_transaction_session_timeout = 0"
        if x : "SET quote_all_identifiers = true"
        if x : "SET row_security = on"
  | --> "BEGIN"
  | --> if pg_dump --serializable-deferrable 
          | --> "SET TRANSACTION ISOLATION LEVEL SERIALIZABLE, READ ONLY, DEFERRABLE"
        else
          | --> "SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY"
```

从代码逻辑上看，使用PQ连接数据库后，首先通过setup_connection函数设定一系列dump数据前的准备工作。其中比较重要的代码即：

```
if pg_dump --serializable-deferrable 
  | --> "SET TRANSACTION ISOLATION LEVEL SERIALIZABLE, READ ONLY, DEFERRABLE"
else
  | --> "SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY"
```

首先回忆一下PG的几种隔离级别



