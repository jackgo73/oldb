# postgresql字符串操作总结（未完）

> gaomingjie
>
> Email: jackgo73@outlook.com
>
> Date:  20180511

## 背景

总结德哥的一些测试用例，学习pg常用的几种字符串搜索方法。

所有SQL出自德哥下面的文章（本文不含全文检索，不做性能测试）

[《HTAP数据库 PostgreSQL 场景与性能测试之 16 - (OLTP) 文本特征向量 - 相似特征(海明...)查询》](https://github.com/digoal/blog/blob/master/201711/20171107_17.md)

[《HTAP数据库 PostgreSQL 场景与性能测试之 14 - (OLTP) 字符串搜索 - 全文检索》](https://github.com/digoal/blog/blob/master/201711/20171107_15.md)

[《HTAP数据库 PostgreSQL 场景与性能测试之 13 - (OLTP) 字符串搜索 - 相似查询》](https://github.com/digoal/blog/blob/master/201711/20171107_14.md)

[《HTAP数据库 PostgreSQL 场景与性能测试之 12 - (OLTP) 字符串搜索 - 前后模糊查询》](https://github.com/digoal/blog/blob/master/201711/20171107_13.md)

[《HTAP数据库 PostgreSQL 场景与性能测试之 11 - (OLTP) 字符串搜索 - 后缀查询》](https://github.com/digoal/blog/blob/master/201711/20171107_12.md)

[《HTAP数据库 PostgreSQL 场景与性能测试之 10 - (OLTP) 字符串搜索 - 前缀查询》](https://github.com/digoal/blog/blob/master/201711/20171107_11.md)

[《HTAP数据库 PostgreSQL 场景与性能测试之 9 - (OLTP) 字符串模糊查询 - 含索引实时写入》](https://github.com/digoal/blog/blob/master/201711/20171107_10.md)

> 字符串搜索是非常常见的业务需求，它包括：
>
> 1、前缀+模糊查询。（可以使用b-tree索引）
>
> 2、后缀+模糊查询。（可以使用b-tree索引）
>
> 3、前后模糊查询。（可以使用pg_trgm和gin索引）
>
> 4、全文检索。（可以使用全文检索类型以及gin或rum索引）
>
> 5、正则查询。（可以使用pg_trgm和gin索引）
>
> 6、相似查询。（可以使用pg_trgm和gin索引）
>
> 通常来说，数据库并不具备3以后的加速能力，但是PostgreSQL的功能非常强大，它可以非常完美的支持这类查询的加速。（是指查询和写入不冲突的，并且索引BUILD是实时的。）
>
> 用户完全不需要将数据同步到搜索引擎，再来查询，而且搜索引擎也只能做到全文检索，并不你做到正则、相似、前后模糊这几个需求。
>
> 使用PostgreSQL可以大幅度的简化用户的架构，开发成本，同时保证数据查询的绝对实时性。

https://github.com/digoal/blog/blob/master/201704/20170426_01.md

## 前言lc_collate是什么？

>  手册23章

区域支持是在使用initdb时自动被初始化的。

默认情况下，initdb将会按照它的执行环境的区域设置初始化数据库集簇； 如果你想使用其它的区域那么你可以用--locale选项准确地告诉initdb你要用哪一个区域。 比如：

```
initdb --locale=sv_SE
```

在你的系统上有哪些区域可用取决于操作系统提供商提供了什么以及安装了什么。在大部分Unix系统上

```
locale -a
```

将会提供一个所有可用区域的列表。

 

区域子类用于控制本地化规则：

| 参数          | 功能                          |
| ----------- | --------------------------- |
| LC_COLLATE  | 字符串排序顺序                     |
| LC_CTYPE    | 字符分类（什么是一个字符？它的大写形式是否等效？）   |
| LC_MESSAGES | 消息使用的语言Language of messages |
| LC_MONETARY | 货币数量使用的格式                   |
| LC_NUMERIC  | 数字的格式                       |
| LC_TIME     | 日期和时间的格式                    |

这些类名转换成initdb的选项名来覆盖某个特定分类的区域选择。比如，要把区域设置为加拿大法语，但使用 U.S. 规则格式化货币，可以使用```initdb --locale=fr_CA --lc-monetary=en_U ```

### 行为 

区域设置特别影响下面的 SQL 特性：

- 在文本数据上使用ORDER BY或标准比较操作符的查询中的排序顺序
- 函数upper、lower和initcap
- 模式匹配操作符（LIKE、SIMILAR TO和POSIX风格的正则表达式）；区域影响大小写不敏感匹配和通过字符类正则表达式的字符分类
- to_char函数家族
- 为LIKE子句使用索引的能力 





.......





## 前缀/后缀查询

前缀

```sql
create table t_prefix (  
  id int,  
  info text  
);  
  
create index idx_t_prefix on t_prefix (info text_pattern_ops);  

insert into t_prefix select id, repeat(md5(random()::Text),4) from generate_series(1,100000) t(id);
```

```sql
postgres=# select * from t_prefix where info like 'a7b669%' limit 1;
 id |                                                               info                                                               
----+----------------------------------------------------------------------------------------------------------------------------------
 30 | a7b669833efb446dba4bfc8fc13872d6a7b669833efb446dba4bfc8fc13872d6a7b669833efb446dba4bfc8fc13872d6a7b669833efb446dba4bfc8fc13872d6
(1 row)

postgres=# explain (analyze, verbose, costs, buffers, timing)select * from t_prefix where info like 'a7b669%' limit 1;
                                                              QUERY PLAN                                                               
---------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=0.54..1.34 rows=1 width=136) (actual time=0.050..0.050 rows=1 loops=1)
   Output: id, info
   Buffers: shared hit=5
   ->  Index Scan using idx_t_prefix on public.t_prefix  (cost=0.54..8.56 rows=10 width=136) (actual time=0.048..0.048 rows=1 loops=1)
         Output: id, info
         Index Cond: ((t_prefix.info ~>=~ 'a7b669'::text) AND (t_prefix.info ~<~ 'a7b66:'::text))
         Filter: (t_prefix.info ~~ 'a7b669%'::text)
         Buffers: shared hit=5
 Planning time: 0.701 ms
 Execution time: 0.111 ms
(10 rows)
```

后缀

```
create table t_suffix (  
  id int,  
  info text  
);  
  
create index idx_t_suffix on t_suffix (reverse(info) text_pattern_ops);  

insert into t_suffix select id, repeat(md5(random()::Text),4) from generate_series(1,100000) t(id);
```

```sql
postgres=# select * from t_suffix where reverse(info) like '6d278%' limit 1;
  id   |                                                               info                                                               
-------+----------------------------------------------------------------------------------------------------------------------------------
 72659 | 514802f04192f0e241fe6004d27872d6514802f04192f0e241fe6004d27872d6514802f04192f0e241fe6004d27872d6514802f04192f0e241fe6004d27872d6
 
postgres=# explain (analyze, verbose, costs, buffers, timing)select * from t_suffix where reverse(info) like '6d278%' limit 1;
                                                              QUERY PLAN                                                               
---------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=0.54..1.34 rows=1 width=136) (actual time=0.062..0.063 rows=1 loops=1)
   Output: id, info
   Buffers: shared hit=5
   ->  Index Scan using idx_t_suffix on public.t_suffix  (cost=0.54..8.57 rows=10 width=136) (actual time=0.060..0.060 rows=1 loops=1)
         Output: id, info
         Index Cond: ((reverse(t_suffix.info) ~>=~ '6d278'::text) AND (reverse(t_suffix.info) ~<~ '6d279'::text))
         Filter: (reverse(t_suffix.info) ~~ '6d278%'::text)
         Buffers: shared hit=5
 Planning time: 0.677 ms
 Execution time: 0.145 ms
(10 rows)
```

## 前后模糊查询

pg_trgm和gin索引

```
create extension pg_trgm;   

create table pre_suffix(c1 text);

create or replace function gen_hanzi(int) returns text as $$                  
declare        
  res text;        
begin        
  if $1 >=1 then        
    select string_agg(chr(19968+(random()*20901)::int), '') into res from generate_series(1,$1);
    return res;        
  end if;        
  return null;        
end;        
$$ language plpgsql strict;

insert into pre_suffix select gen_hanzi(20) from generate_series(1,100000);


create index idx_pre_suffix_1 on pre_suffix using gin (c1 gin_trgm_ops);

postgres=# select * from pre_suffix limit 5;
                    c1                    
------------------------------------------
 藙舌舰籾勸痪鬖飸扢羀詋鑢霰犂惧猢熵晜龟麌
 魪臝骎綫鞣払錉聾載墂譏甽貎淚刖醆闄鼬諙墁
 缇畿黣皒騁急鮴民碀鮮櫸瑅緦旡剋痤稶靔嚾榛
 倱鐍郗躾扂铭肟塡鑴毓拢珖鍒戠鱧趮瑅顶娚黅
 钀眒獥狁軴瞱骥榅潟冾蔠熐韊癒悩婧殚鍈擈恩
(5 rows)
```



```sql
postgres=# explain (analyze,verbose,timing,costs,buffers) select * from pre_suffix where c1 like '%聾載墂%';
                                                            QUERY PLAN                                                            
----------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on public.pre_suffix  (cost=64.08..101.39 rows=10 width=61) (actual time=30.512..76.075 rows=1 loops=1)
   Output: c1
   Recheck Cond: (pre_suffix.c1 ~~ '%聾載墂%'::text)
   Rows Removed by Index Recheck: 99999
   Heap Blocks: exact=1137
   Buffers: shared hit=1155
   ->  Bitmap Index Scan on idx_pre_suffix_1  (cost=0.00..64.08 rows=10 width=0) (actual time=30.213..30.213 rows=100000 loops=1)
         Index Cond: (pre_suffix.c1 ~~ '%聾載墂%'::text)
         Buffers: shared hit=18
 Planning time: 0.318 ms
 Execution time: 76.149 ms
(11 rows)


postgres=# explain (analyze,verbose,timing,costs,buffers) select * from pre_suffix where c1 like '%聾載%';
                                                            QUERY PLAN                                                            
----------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on public.pre_suffix  (cost=64.08..101.39 rows=10 width=61) (actual time=13.369..58.358 rows=1 loops=1)
   Output: c1
   Recheck Cond: (pre_suffix.c1 ~~ '%聾載%'::text)
   Rows Removed by Index Recheck: 99999
   Heap Blocks: exact=1137
   Buffers: shared hit=1155
   ->  Bitmap Index Scan on idx_pre_suffix_1  (cost=0.00..64.08 rows=10 width=0) (actual time=13.203..13.203 rows=100000 loops=1)
         Index Cond: (pre_suffix.c1 ~~ '%聾載%'::text)
         Buffers: shared hit=18
 Planning time: 0.163 ms
 Execution time: 58.417 ms
(11 rows)
```

## 正则匹配查询

PostgreSQL 正则匹配的语法为 `字符串 ~ 'pattern'` 或 `字符串 ~* 'pattern'`

