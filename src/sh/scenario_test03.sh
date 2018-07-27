#!/bin/bash
# Author: Gao Mingjie (jackgo73@outlook.com)


function red_blink () {
        echo -e "\033[5;31m$*\033[0m"
}



psql -c "
drop table if exists t1,t2,t3;
create table t1(
id int8,
id3 int,
info text default 'tessssssssssssssssssssssssssssssssssssst',
state int default 0,
crt_time timestamp default now(),
mod_time timestamp default now()
);

create table t2 (like t1 including all);

create table t3(
id int,
info text default 'tessssssssssssssssssssssssssssssssssssst',
state int default 0,
crt_time timestamp default now(),
mod_time timestamp default now()
);

create index idx_t1_id3 on t1(id3);
create index idx_t2_id3 on t2(id3);
create index idx_t3_id on t3(id);
create index idx_t1_id on t1(id);
create index idx_t2_id on t2(id);
"
red_blink "inserting data..."
psql -c "
insert into t1 select id,random()*1000000 from generate_series(1,100000000) t(id);
insert into t2 select id,random()*1000000 from generate_series(1,100000000) t(id);
insert into t3 select generate_series(1,1000000);
"

rm test03.sql

cat << EOF > test03.sql
\set id random(1,1000000)
select count(*),sum(t1.id3),avg(t1.id3),min(t1.id3),max(t1.id3)
from t1
join t2 using (id)
join t3 on (t1.id3=t3.id)
where t3.id=:id;
EOF

CONNECTS=56
TIMES=300
export PGHOST=$PGDATA
export PGPORT=8400
export PGUSER=postgres
export PGPASSWORD=postgres
export PGDATABASE=postgres

pgbench -M prepared -n -r -P 5 -f ./test03.sql -c $CONNECTS -j $CONNECTS -T $TIMES

rm test03.sql















