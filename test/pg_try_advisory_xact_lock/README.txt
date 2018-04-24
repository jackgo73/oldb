
# pg_try_advisory_xact_lock 与 for update nowait性能对比

```sql
begin;  
select 1 from tbl where id=pk for update nowait;  --  如果用户无法即刻获得锁，则返回错误。从而这个事务回滚。  
update tbl set xxx=xxx,upd_cnt=upd_cnt+1 where id=pk and upd_cnt+1<=5;  
end;  
```

PostgreSQL还提供了一个锁类型，advisory锁，这种锁比行锁更加轻量，支持会话级别和事务级别。（但是需要注意ID是全局的，否则会相互干扰，也就是说，所有参与秒杀或者需要用到advisory lock的ID需要在单个库内保持全局唯一）

例子：
```sql
update tbl set xxx=xxx,upd_cnt=upd_cnt+1 where id=pk and upd_cnt+1<=5 and pg_try_advisory_xact_lock(:id);  
```

对比一下for update nowait和advisory lock的性能。


```sql
create table t1 (id int primary key, info text);
insert into t1 values (1,now()::text);	
select pg_stat_reset();

CREATE OR REPLACE FUNCTION public.f1(i_id integer)    
 RETURNS void    
 LANGUAGE plpgsql    
AS $function$   
declare   
begin   
  perform 1 from t1 where id=i_id for update nowait;   
  update t1 set info=now()::text where id=i_id;   
  exception when others then    
  return;   
end;   
$function$;  

```

开始测试
```
pgbench -M prepared -n -r -P 1 -f ./test_nowat.sql -c 20 -j 20 -T 60

transaction type: ./test_nowat.sql
scaling factor: 1
query mode: prepared
number of clients: 20
number of threads: 20
duration: 10 s
number of transactions actually processed: 138439
latency average = 1.440 ms
latency stddev = 1.607 ms
tps = 13819.192665 (including connections establishing)
tps = 13848.199589 (excluding connections establishing)
script statistics:
 - statement latencies in milliseconds:
         0.001  \set id random(1, 1)
         1.440  select f1(:id);

```

查看统计数据

```
postgres=# select * from pg_stat_all_tables where relname='t1';
-[ RECORD 1 ]-------+-------
relid               | 16736
schemaname          | public
relname             | t1
seq_scan            | 140885
seq_tup_read        | 140885
idx_scan            | 0
idx_tup_fetch       | 0
n_tup_ins           | 0
n_tup_upd           | 856
n_tup_del           | 0
n_tup_hot_upd       | 856
n_live_tup          | 0
n_dead_tup          | 58
n_mod_since_analyze | 856
last_vacuum         | 
last_autovacuum     | 
last_analyze        | 
last_autoanalyze    | 
vacuum_count        | 0
autovacuum_count    | 0
analyze_count       | 0
autoanalyze_count   | 0

```

开始测试
```
pgbench -M prepared -n -r -P 1 -f ./test_advisory.sql -c 20 -j 20 -T 10

transaction type: ./test_advisory.sql
scaling factor: 1
query mode: prepared
number of clients: 20
number of threads: 20
duration: 10 s
number of transactions actually processed: 175787
latency average = 1.135 ms
latency stddev = 1.005 ms
tps = 17571.262085 (including connections establishing)
tps = 17595.547209 (excluding connections establishing)
script statistics:
 - statement latencies in milliseconds:
         0.001  \set id random(1, 1)
         1.134  update t1 set info=now()::text where id=:id and pg_try_advisory_xact_lock(:id);
```

查看统计数据

```

postgres=# select * from pg_stat_all_tables where relname='t1';
-[ RECORD 1 ]-------+-------
relid               | 16736
schemaname          | public
relname             | t1
seq_scan            | 175787
seq_tup_read        | 175787
idx_scan            | 0
idx_tup_fetch       | 0
n_tup_ins           | 0
n_tup_upd           | 959
n_tup_del           | 0
n_tup_hot_upd       | 959
n_live_tup          | 0
n_dead_tup          | 47
n_mod_since_analyze | 959
last_vacuum         | 
last_autovacuum     | 
last_analyze        | 
last_autoanalyze    | 
vacuum_count        | 0
autovacuum_count    | 0
analyze_count       | 0
autoanalyze_count   | 0
```