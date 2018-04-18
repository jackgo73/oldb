# Postgresql逻辑备份与恢复实战

> JackGao
>
> Email: jackgo73@outlook.com
>
> Date:  20180418

## 工具

pg_dump创建的备份在内部是一致的，dump数据pg_dump开始运行时刻的数据库快照，且在pg_dump运行过程中发生的更新将不会被转储。pg_dump工作的时候并不阻塞其他的对数据库的操作。 





