#!/bin/bash
# Author: Gao Mingjie (jackgo73@outlook.com)

psql -c "
drop table if exists t1,t2,t3,t4,t5,t6,t7,t8,t9,t10;

create table t1(  
  id int primary key,  
  info text default 'tessssssssssssssssssssssssssssssssssssst',   
  state int default 0,   
  crt_time timestamp default now(),   
  mod_time timestamp default now()  
);  
  
create table t2 (like t1 including all);  
create table t3 (like t1 including all);  
create table t4 (like t1 including all);  
create table t5 (like t1 including all);  
create table t6 (like t1 including all);  
create table t7 (like t1 including all);  
create table t8 (like t1 including all);  
create table t9 (like t1 including all);  
create table t10 (like t1 including all);  
"
echo -e "\033[5;31minserting data... \033[0m"

psql -c "insert into t1 select generate_series(1,10000000)"  
psql -c "insert into t2 select * from t1"  
psql -c "insert into t3 select * from t1"  
psql -c "insert into t4 select * from t1"  
psql -c "insert into t5 select * from t1"  
psql -c "insert into t6 select * from t1"  
psql -c "insert into t7 select * from t1"  
psql -c "insert into t8 select * from t1"  
psql -c "insert into t9 select * from t1"  
psql -c "insert into t10 select * from t1" 
psql -c "alter role all set join_collapse_limit=1"

rm ./test02.sql
cat << EOF > test02.sql
\set id random(1,10000000)  
select * 
from t1 
  join t2 using (id) 
  join t3 using (id) 
  join t4 using (id) 
  join t5 using (id) 
  join t6 using (id) 
  join t7 using (id) 
  join t8 using (id) 
  join t9 using (id) 
  join t10 using (id) 
where t1.id=:id;  
EOF

CONNECTS=112  
TIMES=300  
export PGHOST=$PGDATA  
export PGPORT=8400 
export PGUSER=postgres
export PGPASSWORD=postgres
export PGDATABASE=postgres

pgbench -M prepared -n -r -P 5 -f ./test02.sql -c $CONNECTS -j $CONNECTS -T $TIMES  

psql -c "
alter role all reset join_collapse_limit
"

rm ./test02.sql
