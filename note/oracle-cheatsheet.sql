-- [ Index ]
-- [ 000000 ] [ 实用SQL ] 
-- [ 000001 ] [ 表空间练习 ] 
-- [ 000002 ] [ EM相关 ]
-- [ 000003 ] [ 用户账户 ]
-----------------------------------------------------------------
-- [ 000002 ] [ EM相关 ]
-- 1 删除EM  emca -deconfig dbcontrol db -repos drop
-- 2 安装EM  emca -config dbcontrol db -repos create 
-----------------------------------------------------------------
-- [ 000001 ] [ 表空间练习 ] 
-- 1 创建表空间
create tablespace newtbs 
datafile '/u01/app/oracle/oradata/ocp11g/newtbs_01.dbf' size 10m
extent management local autoallocate
segment space management auto;
-- 2 创建表，并确定第一个区间的大小
create table newtab(c1 date) tablespace newtbs;
select extent_id, bytes from dba_extents where owner='SYSTEM' and segment_name='NEWTAB';
-- 3 手动添加区间，并重复执行该命令观察每个新区间的大小
alter table newtab allocate extent;
select extent_id, bytes from dba_extents where owner='SYSTEM' and segment_name='NEWTAB';
-- 4 使表空间脱机，再重新联机
alter tablespace newtbs offline;
alter tablespace newtbs online;
insert into newtab values(sysdate);
select * from newtab;
-- 5 将表空间设为只读在设为读写
alter tablespace newtbs read only;
insert into newtab values(sysdate);
drop table newtab;
alter tablespace newtbs read write;
-- 6 启用OMF来创建数据文件
alter system set db_create_file_dest='/u01/app/oracle/oradata/ocp11g';
-- 7 使用最少的语法创建表空间
create tablespace omftbs;
-- 8 确定OMF创建的表空间的属性（初始100M，没有扩展上限）
select file_name, autoextensible, maxbytes, increment_by from dba_data_files where tablespace_name='OMFTBS';
-- 9 调整OMF文件，使特性更合理。
alter database datafile '/u01/app/oracle/oradata/ocp11g/OCP11G/datafile/o1_mf_omftbs_f77j55vo_.dbf' resize 500m;
alter database datafile '/u01/app/oracle/oradata/ocp11g/OCP11G/datafile/o1_mf_omftbs_f77j55vo_.dbf' autoextend on next 100m maxsize 2g;
-- 10 删除表空间
drop tablespace omftbs including contents and datafiles;
-- 11 创建并更改表空间的特性
create tablespace manualsegs segment space management manual;
-- 12 确认新表空间存在
select segment_space_management from dba_tablespaces where tablespace_name='MANUALSEGS';
-- 13 在表空间中创建表和索引（将使用空闲列表来创建这些段）
create table mantab (c1 number) tablespace manualsegs;
create index mantabi on mantab(c1) tablespace manualsegs;
-----------------------------------------------------------------
-- [ 000000 ] [ 实用SQL ] 
-- 表空间文件大小
select t.name, d.name, d.bytes from v$tablespace t join v$datafile d on t.ts# = d.ts# order by t.name;
select tablespace_name,file_name,bytes from dba_data_files order by tablespace_name;
-- 确定control文件位置
select * from v$controlfile;
select value from v$parameter where name='control_files';
-- 确定联机重做日志文件位置和大小
select m.group#,m.member,g.bytes from v$log g join v$logfile m on m.group#=g.group# order by m.group#,m.member;
select member,bytes from v$log join v$logfile using (group#);
-- 确定控制文件的名称和大小
select name, block_size*file_size_blks from v$controlfile;
-- 确定数据文件和临时文件的名称和大小
select name, bytes from v$datafile union all select name, bytes from v$tempfile;
-----------------------------------------------------------------
-- [ 000003 ] [ 用户账户 ]
-- 查询用户表空间及配额（在表空间中可以使用的空间）
select username, DEFAULT_TABLESPACE, temporary_tablespace from dba_users;
select * from database_properties where property_name like '%TABLESPACE';
select * from dba_ts_quotas;
-- 锁定和解锁用户
alter user username account lock;
alter user username account unlock;
-- 强制用户密码过期
alter user username password expire;

