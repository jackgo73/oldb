# 安装PostgresXL

## 部署规划

```
            gtm  <-----  gtm_standby
          /     \
gtm_proxy00      gtm_proxy01    
  /    \           /    \
cn00  dn00       cn01  dn01
                        
```
| node name   | port              | data dir          |
| ----------- | ----------------- | ----------------- |
| gtm         | 9400              | $HOME/app/pgsql00 |
| gtm_standby | 9401              | $HOME/app/pgsql01 |
| gtm_proxy00 | 9402              | $HOME/app/pgsql02 |
| cn00        | 9403 (pool 10403) | $HOME/app/pgsql03 |
| dn00        | 9404              | $HOME/app/pgsql04 |
| gtm_proxy01 | 9405              | $HOME/app/pgsql05 |
| cn01        | 9406 (pool 10406) | $HOME/app/pgsql06 |
| dn01        | 9407              | $HOME/app/pgsql07 |

# 编译安装
```shell
./configure --prefix=$HOME/app/pgsql00 --with-openssl --enable-debug --enable-cassert --enable-thread-safety CFLAGS='-O0' --with-pgport=9400 --enable-depend;make -sj12;make install;
./configure --prefix=$HOME/app/pgsql01 --with-openssl --enable-debug --enable-cassert --enable-thread-safety CFLAGS='-O0' --with-pgport=9401 --enable-depend;make -sj12;make install;
./configure --prefix=$HOME/app/pgsql02 --with-openssl --enable-debug --enable-cassert --enable-thread-safety CFLAGS='-O0' --with-pgport=9402 --enable-depend;make -sj12;make install;
./configure --prefix=$HOME/app/pgsql03 --with-openssl --enable-debug --enable-cassert --enable-thread-safety CFLAGS='-O0' --with-pgport=9403 --enable-depend;make -sj12;make install;
./configure --prefix=$HOME/app/pgsql04 --with-openssl --enable-debug --enable-cassert --enable-thread-safety CFLAGS='-O0' --with-pgport=9404 --enable-depend;make -sj12;make install;
./configure --prefix=$HOME/app/pgsql05 --with-openssl --enable-debug --enable-cassert --enable-thread-safety CFLAGS='-O0' --with-pgport=9405 --enable-depend;make -sj12;make install;
./configure --prefix=$HOME/app/pgsql06 --with-openssl --enable-debug --enable-cassert --enable-thread-safety CFLAGS='-O0' --with-pgport=9406 --enable-depend;make -sj12;make install;
./configure --prefix=$HOME/app/pgsql07 --with-openssl --enable-debug --enable-cassert --enable-thread-safety CFLAGS='-O0' --with-pgport=9407 --enable-depend;make -sj12;make install;
```
## 初始化

### 初始化 & 启动gtm节点

```shell
($PGDATA=$HOME/app/pgsql00)

initgtm -Z gtm -D $PGDATA
sed -ir "s/#*nodename.*/nodename = 'gtm'/" $PGDATA/gtm.conf
sed -ir "s/#*listen_addresses.*/listen_addresses= '*'/" $PGDATA/gtm.conf
sed -ir "s/#*port.*/port = 29400/" $PGDATA/gtm.conf
sed -ir "s/#*startup.*/startup = ACT/" $PGDATA/gtm.conf

gtm_ctl -Z gtm start -D $PGDATA
gtm_ctl -Z gtm status -D $PGDATA
```

### 初始化 & 启动gtm_standby节点
```shell
($PGDATA=$HOME/app/pgsql01)

initgtm -Z gtm -D $PGDATA
sed -ir "s/#*nodename.*/nodename = 'gtm_standby'/" $PGDATA/gtm.conf
sed -ir "s/#*listen_addresses.*/listen_addresses= '*'/" $PGDATA/gtm.conf
sed -ir "s/#*port.*/port = 29401/" $PGDATA/gtm.conf
sed -ir "s/#*startup.*/startup = STANDBY/" $PGDATA/gtm.conf
sed -ir "s/#*active_host.*/active_host = 'localhost'/" $PGDATA/gtm.conf
sed -ir "s/#*active_port.*/active_port = 29400/" $PGDATA/gtm.conf

gtm_ctl -Z gtm start -D $PGDATA
gtm_ctl -Z gtm status -D $PGDATA
```
### 初始化gtm_proxy00, gtm_proxy01节点
####gtm_proxy00
```shell
($PGDATA=$HOME/app/pgsql02)

initgtm -Z gtm_proxy -D $PGDATA
sed -ir "s/#*nodename.*/nodename = 'gtm_proxy00'/" $PGDATA/gtm_proxy.conf
sed -ir "s/#*listen_addresses.*/listen_addresses= '*'/" $PGDATA/gtm_proxy.conf
sed -ir "s/#*port.*/port = 29402/" $PGDATA/gtm_proxy.conf
sed -ir "s/#*gtm_host.*/gtm_host= 'localhost'/" $PGDATA/gtm_proxy.conf
sed -ir "s/#*gtm_port.*/gtm_port = 29400/" $PGDATA/gtm_proxy.conf
sed -ir "s/#*gtm_connect_retry_interval.*/gtm_connect_retry_interval = 1/" $PGDATA/gtm_proxy.conf
sed -ir "s/#*worker_threads.*/worker_threads = 1/" $PGDATA/gtm_proxy.conf

gtm_ctl -Z gtm_proxy start -D $PGDATA
gtm_ctl -Z gtm_proxy status -D $PGDATA
```
####gtm_proxy01
```shell
($PGDATA=$HOME/app/pgsql05)

initgtm -Z gtm_proxy -D $PGDATA
sed -ir "s/#*nodename.*/nodename = 'gtm_proxy01'/" $PGDATA/gtm_proxy.conf
sed -ir "s/#*listen_addresses.*/listen_addresses= '*'/" $PGDATA/gtm_proxy.conf
sed -ir "s/#*port.*/port = 29405/" $PGDATA/gtm_proxy.conf
sed -ir "s/#*gtm_host.*/gtm_host= 'localhost'/" $PGDATA/gtm_proxy.conf
sed -ir "s/#*gtm_port.*/gtm_port = 29400/" $PGDATA/gtm_proxy.conf
sed -ir "s/#*gtm_connect_retry_interval.*/gtm_connect_retry_interval = 1/" $PGDATA/gtm_proxy.conf
sed -ir "s/#*worker_threads.*/worker_threads = 1/" $PGDATA/gtm_proxy.conf

gtm_ctl -Z gtm_proxy start -D $PGDATA
gtm_ctl -Z gtm_proxy status -D $PGDATA
```
### 初始化cn节点
####cn00(FIRST CN)
```shell
($PGDATA=$HOME/app/pgsql03)

initdb --nodename cn00 -D $PGDATA
sed -ir "s/#*listen_addresses.*/listen_addresses = '*'/" $PGDATA/postgresql.conf
sed -ir "s/#*port.*/port = 29403/" $PGDATA/postgresql.conf
sed -ir "s/#*logging_collector.*/logging_collector= on/" $PGDATA/postgresql.conf
sed -ir "s/#*log_directory.*/log_directory = 'pg_log'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_filename.*/log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_rotation_size.*/log_rotation_size = 10MB/" $PGDATA/postgresql.conf
sed -ir "s/#*log_line_prefix.*/log_line_prefix='%p %r %u %d %t %e'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_min_duration_statement.*/log_min_duration_statement= 1000/" $PGDATA/postgresql.conf
sed -ir "s/#*log_timezone.*/log_timezone = 'UTC'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_truncate_on_rotation.*/log_truncate_on_rotation = on/" $PGDATA/postgresql.conf
sed -ir "s/#*log_rotation_age.*/log_rotation_age = 0/" $PGDATA/postgresql.conf
sed -ir "s/#*log_statement.*/log_statement= 'all'/" $PGDATA/postgresql.conf
sed -ir "s/#*max_prepared_transactions.*/max_prepared_transactions= 800/" $PGDATA/postgresql.conf

sed -ir "s/#*gtm_host.*/gtm_host = 'localhost'/" $PGDATA/postgresql.conf
sed -ir "s/#*gtm_port.*/gtm_port = 29402/" $PGDATA/postgresql.conf
sed -ir "s/#*pgxc_node_name.*/pgxc_node_name = 'cn00'/" $PGDATA/postgresql.conf
sed -ir "s/#*pooler_port.*/pooler_port= 29413/" $PGDATA/postgresql.conf


pg_ctl start -w -Z coordinator -D $PGDATA -o -i

psql -p 29403 postgres -c "ALTER NODE cn00 WITH (host='localhost', PORT=29403)"
psql -p 29403 postgres -c "SELECT pgxc_pool_reload()"
```



####cn01(NOT FIRST CN)
```shell
($PGDATA=$HOME/app/pgsql06)

initdb --nodename cn01 -D $PGDATA
sed -ir "s/#*listen_addresses.*/listen_addresses = '*'/" $PGDATA/postgresql.conf
sed -ir "s/#*port.*/port = 29406/" $PGDATA/postgresql.conf
sed -ir "s/#*logging_collector.*/logging_collector= on/" $PGDATA/postgresql.conf
sed -ir "s/#*log_directory.*/log_directory = 'pg_log'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_filename.*/log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_rotation_size.*/log_rotation_size = 10MB/" $PGDATA/postgresql.conf
sed -ir "s/#*log_line_prefix.*/log_line_prefix='%p %r %u %d %t %e'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_min_duration_statement.*/log_min_duration_statement= 1000/" $PGDATA/postgresql.conf
sed -ir "s/#*log_timezone.*/log_timezone = 'UTC'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_truncate_on_rotation.*/log_truncate_on_rotation = on/" $PGDATA/postgresql.conf
sed -ir "s/#*log_rotation_age.*/log_rotation_age = 0/" $PGDATA/postgresql.conf
sed -ir "s/#*log_statement.*/log_statement= 'all'/" $PGDATA/postgresql.conf
sed -ir "s/#*max_prepared_transactions.*/max_prepared_transactions= 800/" $PGDATA/postgresql.conf

sed -ir "s/#*gtm_host.*/gtm_host = 'localhost'/" $PGDATA/postgresql.conf
sed -ir "s/#*gtm_port.*/gtm_port = 29405/" $PGDATA/postgresql.conf
sed -ir "s/#*pgxc_node_name.*/pgxc_node_name = 'cn01'/" $PGDATA/postgresql.conf
sed -ir "s/#*pooler_port.*/pooler_port= 29416/" $PGDATA/postgresql.conf
```
(keep session opening)(导出数据)
```shell
($PGDATA=$HOME/app/pgsql03)
psql -p 29403 postgres
select pgxc_lock_for_backup(); #keep session opening

pg_dumpall -p 29403 -h localhost -s --include-nodes --dump-nodes --file=/tmp/cndumpfile.sql
```
(灌入数据：灌入目前集群中其他节点信息)
```shell
pg_ctl start -w -Z restoremode -D $PGDATA -o -i
psql -h localhost -p 29406 -d postgres -f /tmp/cndumpfile.sql
rm -f /tmp/cndumpfile.sql
pg_ctl stop -w -Z restoremode -D $PGDATA
```
(修改自己的node信息)
```shell
pg_ctl start -w -Z coordinator -D $PGDATA -o -i
psql -p 29406 postgres -c "ALTER NODE cn01 WITH (host='localhost', PORT=29406)"
psql -p 29406 postgres -c "SELECT pgxc_pool_reload()"
```
(如果有其他CN)
```shell
##if (get any available coordinator if there is)
($PGDATA=$HOME/app/pgsql03)
(at all other cn)

psql -p 29403 postgres -c "CREATE NODE cn01 WITH (TYPE = 'coordinator', host='localhost', PORT=29406)"
psql -p 29403 postgres -c "SELECT pgxc_pool_reload()"
```

(如果有DN)
```shell
##if (get any available datanode if there is)
(at all other dn)
EXECUTE DIRECT ON ( ? ) 'CREATE NODE cn01 WITH (TYPE = ''coordinator'', host=''localhost'', PORT=29406)';
EXECUTE DIRECT ON ( ? ) 'SELECT pgxc_pool_reload()';
```
(close lock session)

### 初始化dn节点
####dn00(FIRST DN)

```shell
($PGDATA=$HOME/app/pgsql04)

initdb --nodename dn00 -D $PGDATA
sed -ir "s/#*listen_addresses.*/listen_addresses = '*'/" $PGDATA/postgresql.conf
sed -ir "s/#*port.*/port = 29404/" $PGDATA/postgresql.conf
sed -ir "s/#*pooler_port.*/pooler_port = 29414/" $PGDATA/postgresql.conf
sed -ir "s/#*logging_collector.*/logging_collector= on/" $PGDATA/postgresql.conf
sed -ir "s/#*log_directory.*/log_directory = 'pg_log'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_filename.*/log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_rotation_size.*/log_rotation_size = 10MB/" $PGDATA/postgresql.conf
sed -ir "s/#*log_line_prefix.*/log_line_prefix='%p %r %u %d %t %e'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_min_duration_statement.*/log_min_duration_statement= 1000/" $PGDATA/postgresql.conf
sed -ir "s/#*log_timezone.*/log_timezone = 'UTC'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_truncate_on_rotation.*/log_truncate_on_rotation = on/" $PGDATA/postgresql.conf
sed -ir "s/#*log_rotation_age.*/log_rotation_age = 0/" $PGDATA/postgresql.conf
sed -ir "s/#*log_statement.*/log_statement= 'all'/" $PGDATA/postgresql.conf
sed -ir "s/#*max_prepared_transactions.*/max_prepared_transactions= 800/" $PGDATA/postgresql.conf

sed -ir "s/#*gtm_host.*/gtm_host = 'localhost'/" $PGDATA/postgresql.conf
sed -ir "s/#*gtm_port.*/gtm_port = 29402/" $PGDATA/postgresql.conf
sed -ir "s/#*pgxc_node_name.*/pgxc_node_name = 'dn00'/" $PGDATA/postgresql.conf
```
####if (get any available datanode if there is)
```shell
dump data from dn
```
####else (get any available coordinator if there is)

(keep session opening)(导出数据)
```shell
psql -p 29406 postgres
select pgxc_lock_for_backup(); #keep session opening
pg_dumpall -p 29406 -h localhost -s --include-nodes --dump-nodes > /tmp/cndumpfile.sql
```
(灌入数据：灌入目前集群中其他节点信息)
```shell
pg_ctl restart -w -Z restoremode -D $PGDATA -o -i
psql -h localhost -p 29404 -d postgres -f /tmp/cndumpfile.sql
rm -f /tmp/cndumpfile.sql
pg_ctl stop -w -Z restoremode -D $PGDATA
pg_ctl start -w -Z datanode -D $PGDATA -o -i
```
(在所有的coord上面创建该dn)
```shell
psql -p 29403 postgres -c "CREATE NODE dn00 WITH (TYPE = 'datanode', host='localhost', PORT=29404)"
psql -p 29403 postgres -c "SELECT pgxc_pool_reload()"

psql -p 29406 postgres -c "CREATE NODE dn00 WITH (TYPE = 'datanode', host='localhost', PORT=29404)"
psql -p 29406 postgres -c "SELECT pgxc_pool_reload()"
```
(通过某个cn，把dn上的所有node信息配好)(当前只有一个DN)
```shell
psql -p 29403 postgres -c "EXECUTE DIRECT ON (dn00) 'ALTER NODE dn00 WITH (TYPE = ''datanode'', host=''localhost'', PORT=29404)'"
psql -p 29403 postgres -c "EXECUTE DIRECT ON (dn00) 'SELECT pgxc_pool_reload()'"
```
(close lock session)

####dn01(NOT FIRST DN)
```shell
($PGDATA=$HOME/app/pgsql07)

initdb --nodename dn01 -D $PGDATA
sed -ir "s/#*listen_addresses.*/listen_addresses = '*'/" $PGDATA/postgresql.conf
sed -ir "s/#*port.*/port = 29407/" $PGDATA/postgresql.conf
sed -ir "s/#*pooler_port.*/pooler_port = 29417/" $PGDATA/postgresql.conf
sed -ir "s/#*logging_collector.*/logging_collector= on/" $PGDATA/postgresql.conf
sed -ir "s/#*log_directory.*/log_directory = 'pg_log'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_filename.*/log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_rotation_size.*/log_rotation_size = 10MB/" $PGDATA/postgresql.conf
sed -ir "s/#*log_line_prefix.*/log_line_prefix='%p %r %u %d %t %e'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_min_duration_statement.*/log_min_duration_statement= 1000/" $PGDATA/postgresql.conf
sed -ir "s/#*log_timezone.*/log_timezone = 'UTC'/" $PGDATA/postgresql.conf
sed -ir "s/#*log_truncate_on_rotation.*/log_truncate_on_rotation = on/" $PGDATA/postgresql.conf
sed -ir "s/#*log_rotation_age.*/log_rotation_age = 0/" $PGDATA/postgresql.conf
sed -ir "s/#*log_statement.*/log_statement= 'all'/" $PGDATA/postgresql.conf
sed -ir "s/#*max_prepared_transactions.*/max_prepared_transactions= 800/" $PGDATA/postgresql.conf

sed -ir "s/#*gtm_host.*/gtm_host = 'localhost'/" $PGDATA/postgresql.conf
sed -ir "s/#*gtm_port.*/gtm_port = 29405/" $PGDATA/postgresql.conf
sed -ir "s/#*pgxc_node_name.*/pgxc_node_name = 'dn01'/" $PGDATA/postgresql.conf
```

####if (get any available datanode if there is)
```shell
#dump data from dn
psql -p 29404 postgres
select pgxc_lock_for_backup(); #keep session opening
pg_dumpall -p 29404 -h localhost -s --include-nodes --dump-nodes > /tmp/dndumpfile.sql
```
(灌入数据：灌入目前集群中其他节点信息)
```shell
pg_ctl restart -w -Z restoremode -D $PGDATA -o -i
psql -h localhost -p 29407 -d postgres -f /tmp/dndumpfile.sql
rm -f /tmp/cndumpfile.sql
pg_ctl stop -w -Z restoremode -D $PGDATA
pg_ctl start -w -Z datanode -D $PGDATA -o -i
```
(在所有的coord上面创建该dn)
```shell
psql -p 29403 postgres -c "CREATE NODE dn01 WITH (TYPE = 'datanode', host='localhost', PORT=29407)"
psql -p 29403 postgres -c "SELECT pgxc_pool_reload()"

psql -p 29406 postgres -c "CREATE NODE dn01 WITH (TYPE = 'datanode', host='localhost', PORT=29407)"
psql -p 29406 postgres -c "SELECT pgxc_pool_reload()"
```
(通过某个cn，把dn上的所有node信息配好)(当前有两个DN)
```shell
psql -p 29403 postgres -c "EXECUTE DIRECT ON (dn00) 'CREATE NODE dn01 WITH (TYPE = ''datanode'', host=''localhost'', PORT=29407)'"
psql -p 29403 postgres -c "EXECUTE DIRECT ON (dn00) 'SELECT pgxc_pool_reload()'"
psql -p 29403 postgres -c "EXECUTE DIRECT ON (dn01) 'ALTER NODE dn01 WITH (TYPE = ''datanode'', host=''localhost'', PORT=29407)'"
psql -p 29403 postgres -c "EXECUTE DIRECT ON (dn01) 'SELECT pgxc_pool_reload()'"
```
(close lock session)

## 例子


```sql
postgres=# CREATE TABLE disttab(col1 int, col2 int, col3 text) DISTRIBUTE BY HASH(col1);
CREATE TABLE

postgres=# INSERT INTO disttab SELECT generate_series(1,100), generate_series(101, 200), 'foo';
INSERT 0 100

postgres=# CREATE TABLE repltab (col1 int, col2 int) DISTRIBUTE BY REPLICATION;
CREATE TABLE

postgres=# INSERT INTO repltab SELECT generate_series(1,100), generate_series(101, 200);
INSERT 0 100

postgres=# SELECT xc_node_id, count(*) FROM disttab GROUP BY xc_node_id;
 xc_node_id  | count 
-------------+-------
 -1085152094 |    58
   344264856 |    42
(2 rows)

postgres=# SELECT xc_node_id, count(*) FROM repltab GROUP BY xc_node_id;
 xc_node_id  | count 
-------------+-------
 -1085152094 |   100
(1 row)
```
ALTER TABLE
```sql
postgres=# ALTER TABLE disttab DELETE NODE (dn01);
ALTER TABLE

postgres=# SELECT xc_node_id, count(*) FROM disttab GROUP BY xc_node_id;
 xc_node_id | count 
------------+-------
  344264856 |   100
(1 row)

postgres=# ALTER TABLE disttab ADD NODE (dn01);
ALTER TABLE

postgres=# SELECT xc_node_id, count(*) FROM disttab GROUP BY xc_node_id;
 xc_node_id  | count 
-------------+-------
 -1085152094 |    58
   344264856 |    42
(2 rows)

postgres=# ALTER TABLE repltab DISTRIBUTE BY HASH(col1);
ALTER TABLE

postgres=# SELECT xc_node_id, count(*) FROM repltab GROUP BY xc_node_id;
 xc_node_id  | count 
-------------+-------
 -1085152094 |    58
   344264856 |    42
(2 rows)

postgres=# ALTER TABLE repltab DISTRIBUTE BY REPLICATION;
ALTER TABLE

postgres=# SELECT xc_node_id, count(*) FROM repltab GROUP BY xc_node_id;
 xc_node_id  | count 
-------------+-------
 -1085152094 |   100
(1 row)
```

Let us try to remove a datanode now.
```sql
postgres=# SELECT oid, * FROM pgxc_node;
  oid  | node_name | node_type | node_port | node_host | nodeis_primary | nodeis_preferred |   node_id   
-------+-----------+-----------+-----------+-----------+----------------+------------------+-------------
 11739 | cn00      | C         |     29403 | localhost | f              | f                |   725349144
 16384 | cn01      | C         |     29406 | localhost | f              | f                |    53994174
 16385 | dn00      | D         |     29404 | localhost | f              | f                |   344264856
 16386 | dn01      | D         |     29407 | localhost | f              | f                | -1085152094
(4 rows)

postgres=# select * from pgxc_class;
 pcrelid | pclocatortype | pcattnum | pchashalgorithm | pchashbuckets |  nodeoids   
---------+---------------+----------+-----------------+---------------+-------------
   16393 | H             |        1 |               1 |          4096 | 16385 16386
   16399 | R             |        0 |               0 |             0 | 16385 16386
(2 rows)
```

| Name            | Type      | References    | Description                              |
| --------------- | --------- | ------------- | ---------------------------------------- |
| pcrelid         | oid       | pg_class.oid  | OID of the table                         |
| pclocatortype   | char      |               | Type of locator                          |
| pcattnum        | int2      |               | Column number of used as distribution key |
| pchashalgorithm | int2      |               | Indicates hashing algorithm used to distribute the tuples |
| pchashbuckets   | int2      |               | Indicates the number of hash buckets used to distribute duple |
| nodeoids        | oidvector | pgxc_node.oid | List of node OIDs where table is located. This list is ordered by pgxc_node.node_name. This list is then indexed in information in user session cache and reused as a node target list when doing SQL operations on cluster tables |

```sql
postgres=# SELECT * FROM pgxc_class WHERE nodeoids::integer[] @> ARRAY[16386];
 pcrelid | pclocatortype | pcattnum | pchashalgorithm | pchashbuckets |  nodeoids   
---------+---------------+----------+-----------------+---------------+-------------
   16393 | H             |        1 |               1 |          4096 | 16385 16386
   16399 | R             |        0 |               0 |             0 | 16385 16386
(2 rows)

postgres=# SELECT * FROM pgxc_class WHERE pcrelid=16393 AND nodeoids::integer[] @> ARRAY[16386];
 pcrelid | pclocatortype | pcattnum | pchashalgorithm | pchashbuckets |  nodeoids   
---------+---------------+----------+-----------------+---------------+-------------
   16393 | H             |        1 |               1 |          4096 | 16385 16386
(1 row)

postgres=# ALTER TABLE disttab DELETE NODE (dn01);
ALTER TABLE

postgres=# SELECT * FROM pgxc_class WHERE pcrelid=16393 AND nodeoids::integer[] @> ARRAY[16386];
 pcrelid | pclocatortype | pcattnum | pchashalgorithm | pchashbuckets | nodeoids 
---------+---------------+----------+-----------------+---------------+----------
(0 rows)
```



