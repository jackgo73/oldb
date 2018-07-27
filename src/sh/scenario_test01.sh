#!/bin/bash
# Author: Gao Mingjie (jackgo73@outlook.com)

psql -c "
create table test(  
  id int8 primary key,   
  info text default 'tessssssssssssssssssssssssssssssssssssst',   
  state int default 0,   
  crt_time timestamp default now(),   
  mod_time timestamp default now()  
)"
psql -c "truncate test"

echo -e "\033[5;31m inserting data... \033[0m"

psql -c "insert into test select generate_series(1,100000000)"

rm ./test01.sql
cat << EOF > test01.sql
\set id random(1,100000000)
select * from test where id=:id;
EOF


CONNECTS=112  
TIMES=300 
export PGHOST=$PGDATA  
export PGPORT=8400
export PGUSER=postgres  
export PGPASSWORD=postgres  
export PGDATABASE=postgres

pgbench -M prepared -n -r -P 5 -f ./test01.sql -c $CONNECTS -j $CONNECTS -T $TIMES 

rm ./test01.sql


# progress: 295.0 s, 4969.6 tps, lat 22.548 ms stddev 23.508
# progress: 300.0 s, 4559.1 tps, lat 24.577 ms stddev 27.826
# transaction type: ./test.sql
# scaling factor: 1
# query mode: prepared
# number of clients: 112
# number of threads: 112
# duration: 300 s
# number of transactions actually processed: 1754713
# latency average = 19.140 ms
# latency stddev = 23.234 ms
# tps = 5845.850846 (including connections establishing)
# tps = 5849.152002 (excluding connections establishing)
# script statistics:
#  - statement latencies in milliseconds:
#          0.002  \set id random(1,100000000)
#         19.143  select * from test where id=:id;