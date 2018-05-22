# Postgresql DDL 审计实战

> gaomingjie
>
> Email: jackgo73@outlook.com
>
> Date:  20180522

## 背景

DDL审计在业务线提出过类似的功能， 之前的版本修改源码实现了审计日志系统表，今天看到德哥使用触发器就能实现同样功能，这里实践一把！

原文：https://github.com/digoal/blog/blob/master/201709/20170925_02.md



## 手册Ch38

- 为了对Chapter 37中讨论的触发器机制加以补充， PostgreSQL也提供了事件触发器


- 和常规触发器（附着在 一个表上并且只捕捉 DML 事件）不同，事件触发器对一个特定数据库来说是全局 的，并且可以捕捉 DDL 事件，和常规触发器相似。


- 可以用任何包括了事件触发器支持的过程语言或者 C 编写 事件触发器，但是不能用纯 SQL 编写。 

- 当 前 支 持 的 事 件 是

  - ddl_command_start

    在CREATE、 ALTER、DROP、SECURITY LABEL、COMMENT、GRANT或者REVOKE 命令的执行之前发生。在事件触发器引发前不会做受影响对象是否存在的检查。 不过，一个例外是，这个事件不会为目标是共享对象 — 数据库、角色 以及表空间 — 的 DDL 命令发生，也不会为目标是事件触发器的 DDL 命令发生。事件触发器机制不支持这些对象类型。 ddl_command_start也会在SELECT INTO 命令的执行之前发生，因为这等价于 CREATE TABLE AS 


  - ddl_command_end

    在 同 一 组 命 令 的 执 行 之 后 发 生 。 为 了 得 到 发 生 的DDL操作 的 更 多 细 节 ， 可 以 从 ddl_command_end事 件 触 发 器 代 码 中 使 用 集 合 返 回 函 数pg_event_trigger_ddl_commands()（见 Section 9.28）。注意该触发器是在那些动作 已经发生之后（但是在事务提交前）引发，并且因此系统目录会被读作已更改。 

  - table_rewrite

    在表被命令ALTER TABLE和 ALTER TYPE的某些动作重写之前发生。虽然其他控制语句（例如 CLUSTER和VACUUM）也可以用来重 写表，但是它们不会触发table_rewrite事件。 

  - sql_drop 



## SQL

https://github.com/digoal/blog/blob/master/201709/20170925_02.md

```sql
\c template1 postgres

create schema pgaudit;  
grant USAGE on schema pgaudit to public;  
  
create table pgaudit.audit_ddl_command_end (    
  event text,    
  tag text,    
  username name default current_user,    
  datname name default current_database(),    
  client_addr inet default inet_client_addr(),    
  client_port int default inet_client_port(),    
  crt_time timestamp default now(),    
  classid oid,    
  objid oid,    
  objsubid int,    
  command_tag text,    
  object_type text,    
  schema_name text,    
  object_identity text,    
  is_extension bool,    
  xid bigint default txid_current()  
);    
    
create table pgaudit.audit_sql_drop (    
  event text,    
  tag text,    
  username name default current_user,    
  datname name default current_database(),    
  client_addr inet default inet_client_addr(),    
  client_port int default inet_client_port(),    
  crt_time timestamp default now(),    
  classid oid,    
  objid oid,    
  objsubid int,    
  original bool,    
  normal bool,    
  is_temporary bool,    
  object_type text,    
  schema_name text,    
  object_name text,    
  object_identity text,    
  address_names text[],    
  address_args text[],    
  xid bigint default txid_current()   
);    
    
create table pgaudit.audit_table_rewrite (    
  event text,    
  tag text,    
  username name default current_user,    
  datname name default current_database(),    
  client_addr inet default inet_client_addr(),    
  client_port int default inet_client_port(),    
  crt_time timestamp default now(),    
  table_rewrite_oid oid,    
  table_rewrite_reason int,    
  xid bigint default txid_current()  
);    
    
grant select,update,delete,insert,truncate on pgaudit.audit_ddl_command_end to public;    
grant select,update,delete,insert,truncate on pgaudit.audit_sql_drop to public;    
grant select,update,delete,insert,truncate on pgaudit.audit_table_rewrite to public; 

```
使用纯pl/pgsql实现触发器函数 && 创建事件触发器
```sql

create or replace function pgaudit.et_ddl_command_end() returns event_trigger as $$    
declare    
begin    
  insert into pgaudit.audit_ddl_command_end (event, tag, classid, objid, objsubid, command_tag, object_type, schema_name, object_identity, is_extension )    
    select TG_EVENT, TG_TAG,      
      classid, objid, objsubid, command_tag, object_type, schema_name, object_identity, in_extension from    
      pg_event_trigger_ddl_commands();    
  exception when others then  --	ERROR:  22004: null values cannot be formatted as an SQL identifier  
  return;    
end;    
$$ language plpgsql strict;    

create or replace function pgaudit.et_sql_drop() returns event_trigger as $$    
declare    
begin    
  insert into pgaudit.audit_sql_drop (event, tag, classid, objid, objsubid, original, normal, is_temporary, object_type, schema_name, object_name, object_identity, address_names, address_args)    
    select TG_EVENT, TG_TAG,  
      classid, objid, objsubid, original, normal, is_temporary, object_type, schema_name, object_name, object_identity, address_names, address_args from    
      pg_event_trigger_dropped_objects();    
  exception when others then  --	ERROR:  22004: null values cannot be formatted as an SQL identifier  
  return;    
end;    
$$ language plpgsql strict;    

create or replace function pgaudit.et_table_rewrite() returns event_trigger as $$    
declare    
begin    
  insert into pgaudit.audit_table_rewrite (event, tag, table_rewrite_oid, table_rewrite_reason)     
    select TG_EVENT, TG_TAG,      
      pg_event_trigger_table_rewrite_oid(),    
      pg_event_trigger_table_rewrite_reason();    
  exception when others then  --	ERROR:  22004: null values cannot be formatted as an SQL identifier  
  return;    
end;    
$$ language plpgsql strict;   

CREATE EVENT TRIGGER et_ddl_command_end on ddl_command_end EXECUTE PROCEDURE pgaudit.et_ddl_command_end();    
    
CREATE EVENT TRIGGER et_sql_drop on sql_drop EXECUTE PROCEDURE pgaudit.et_sql_drop();    
    
CREATE EVENT TRIGGER et_table_rewrite on table_rewrite EXECUTE PROCEDURE pgaudit.et_table_rewrite();    

```

在表上挂普通触发器做事件通知
```sql

create or replace function pgaudit.tg1() returns trigger as $$  
declare  
  v_class_nsp name;  
  v_class_name name;  
  v_obj json;  
begin  
  select t2.nspname,t1.relname into v_class_nsp,v_class_name from pg_class t1,pg_namespace t2 where t1.oid=NEW.classid and t1.relnamespace=t2.oid;  
  
  execute format('select row_to_json(t) from %I.%I t where oid=%s', v_class_nsp, v_class_name, NEW.objid) into v_obj;  
  
  -- raise notice 'CLASS_NSP:%, CLASS_NAME:%, OBJ:%, CONTENT:%', v_class_nsp, v_class_name, v_obj, row_to_json(NEW);  
    
  perform pg_notify('ddl_event', format('CLASS_NSP:%s, CLASS_NAME:%s, OBJ:%s, CONTENT:%s', v_class_nsp, v_class_name, v_obj, row_to_json(NEW)));  
  return null;  
end;  
$$ language plpgsql strict;  
  
create trigger tg1 after insert on pgaudit.audit_ddl_command_end for each row execute procedure pgaudit.tg1();  

create or replace function pgaudit.tg2() returns trigger as $$  
declare  
  v_class_nsp name;  
  v_class_name name;  
  v_obj json;  
begin  
  select t2.nspname,t1.relname into v_class_nsp,v_class_name from pg_class t1,pg_namespace t2 where t1.oid=NEW.classid and t1.relnamespace=t2.oid;  
  
  execute format('select row_to_json(t) from %I.%I t where oid=%s', v_class_nsp, v_class_name, NEW.objid) into v_obj;  
  
  -- raise notice 'CLASS_NSP:%, CLASS_NAME:%, OBJ:%, CONTENT:%', v_class_nsp, v_class_name, v_obj, row_to_json(NEW);  
    
  perform pg_notify('ddl_event', format('CLASS_NSP:%s, CLASS_NAME:%s, OBJ:%s, CONTENT:%s', v_class_nsp, v_class_name, v_obj, row_to_json(NEW)));  
  return null;  
end;  
$$ language plpgsql strict;  
  
create trigger tg2 after insert on pgaudit.audit_sql_drop for each row execute procedure pgaudit.tg2();  

create or replace function pgaudit.tg3() returns trigger as $$  
declare  
begin  
  -- raise notice 'TABLE:%, CONTENT:%', (NEW.table_rewrite_oid)::regclass, row_to_json(NEW);  
    
  perform pg_notify('ddl_event', format('TABLE:%s, CONTENT:%s', (NEW.table_rewrite_oid)::regclass, row_to_json(NEW)));  
  return null;  
end;  
$$ language plpgsql strict;  
  
create trigger tg3 after insert on pgaudit.audit_table_rewrite for each row execute procedure pgaudit.tg3();  


create database db1 template template1;

\c db1

listen ddl_event;

create table tbl(id int); 
insert into tbl select generate_series(1,100); 
alter table tbl add column info text default 'abc';
drop table tbl;

select * from pgaudit.audit_ddl_command_end ;
select * from pgaudit.audit_sql_drop ;
select * from pgaudit.audit_table_rewrite ;
```

## 相关函数定义

**pg_event_trigger_ddl_commands()**

| Name              | Type             | Description                              |
| ----------------- | ---------------- | ---------------------------------------- |
| `classid`         | `Oid`            | OID of catalog the object belongs in     |
| `objid`           | `Oid`            | OID of the object in the catalog         |
| `objsubid`        | `integer`        | Object sub-id (e.g. attribute number for columns) |
| `command_tag`     | `text`           | command tag                              |
| `object_type`     | `text`           | Type of the object                       |
| `schema_name`     | `text`           | Name of the schema the object belongs in, if any; otherwise `NULL`. No quoting is applied. |
| `object_identity` | `text`           | Text rendering of the object identity, schema-qualified. Each and every identifier present in the identity is quoted if necessary. |
| `in_extension`    | `bool`           | whether the command is part of an extension script |
| `command`         | `pg_ddl_command` | A complete representation of the command, in internal format. This cannot be output directly, but it can be passed to other functions to obtain different pieces of information about the command. |

**pg_event_trigger_dropped_objects()**

| Name              | Type     | Description                              |
| ----------------- | -------- | ---------------------------------------- |
| `classid`         | `Oid`    | OID of catalog the object belonged in    |
| `objid`           | `Oid`    | OID the object had within the catalog    |
| `objsubid`        | `int32`  | Object sub-id (e.g. attribute number for columns) |
| `original`        | `bool`   | Flag used to identify the root object(s) of the deletion |
| `normal`          | `bool`   | Flag indicating that there's a normal dependency relationship in the dependency graph leading to this object |
| `is_temporary`    | `bool`   | Flag indicating that the object was a temporary object. |
| `object_type`     | `text`   | Type of the object                       |
| `schema_name`     | `text`   | Name of the schema the object belonged in, if any; otherwise `NULL`. No quoting is applied. |
| `object_name`     | `text`   | Name of the object, if the combination of schema and name can be used as a unique identifier for the object; otherwise `NULL`. No quoting is applied, and name is never schema-qualified. |
| `object_identity` | `text`   | Text rendering of the object identity, schema-qualified. Each and every identifier present in the identity is quoted if necessary. |
| `address_names`   | `text[]` | An array that, together with `object_type` and `address_args`, can be used by the `pg_get_object_address()` to recreate the object address in a remote server containing an identically named object of the same kind. |
| `address_args`    | `text[]` | Complement for `address_names` above.    |

**pg_event_trigger_table_rewrite_oid()**
**pg_event_trigger_table_rewrite_reason()**

| Name                                     | Return Type | Description                              |
| ---------------------------------------- | ----------- | ---------------------------------------- |
| `pg_event_trigger_table_rewrite_oid()`   | `Oid`       | The OID of the table about to be rewritten. |
| `pg_event_trigger_table_rewrite_reason()` | `int`       | The reason code(s) explaining the reason for rewriting. The exact meaning of the codes is release dependent. |

