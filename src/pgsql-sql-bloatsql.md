# 拆解分析德哥给出的表膨胀检测SQL

> jackgao  20180625  jackgo73@outlook.com

经常用德哥给出的表膨胀和索引膨胀检测SQL，这里拆解开逐项做下分析，是个学习长SQL、函数、系统表非常不错的案例。

## 表膨胀SQL

引用SQL原文地址：https://github.com/digoal/pgsql_admin_script/blob/master/generate_report.sh



**看长SQL的时候其实只要看清楚层次就不难分析了，这个SQL涉及的知识点很多，下面先贴出完整SQL然后逐层拆解简化分析：**

```sql
SELECT  
  current_database() AS db, schemaname, tablename, reltuples::bigint AS tups, relpages::bigint AS pages, otta,  
  ROUND(CASE WHEN otta=0 OR sml.relpages=0 OR sml.relpages=otta THEN 0.0 ELSE sml.relpages/otta::numeric END,1) AS tbloat,  
  CASE WHEN relpages < otta THEN 0 ELSE relpages::bigint - otta END AS wastedpages,  
  CASE WHEN relpages < otta THEN 0 ELSE bs*(sml.relpages-otta)::bigint END AS wastedbytes,  
  CASE WHEN relpages < otta THEN $$0 bytes$$::text ELSE (bs*(relpages-otta))::bigint || $$ bytes$$ END AS wastedsize,  
  iname, ituples::bigint AS itups, ipages::bigint AS ipages, iotta,  
  ROUND(CASE WHEN iotta=0 OR ipages=0 OR ipages=iotta THEN 0.0 ELSE ipages/iotta::numeric END,1) AS ibloat,  
  CASE WHEN ipages < iotta THEN 0 ELSE ipages::bigint - iotta END AS wastedipages,  
  CASE WHEN ipages < iotta THEN 0 ELSE bs*(ipages-iotta) END AS wastedibytes,  
  CASE WHEN ipages < iotta THEN $$0 bytes$$ ELSE (bs*(ipages-iotta))::bigint || $$ bytes$$ END AS wastedisize,  
  CASE WHEN relpages < otta THEN  
    CASE WHEN ipages < iotta THEN 0 ELSE bs*(ipages-iotta::bigint) END  
    ELSE CASE WHEN ipages < iotta THEN bs*(relpages-otta::bigint)  
      ELSE bs*(relpages-otta::bigint + ipages-iotta::bigint) END  
  END AS totalwastedbytes  
FROM (  
  SELECT  
    nn.nspname AS schemaname,  
    cc.relname AS tablename,  
    COALESCE(cc.reltuples,0) AS reltuples,  
    COALESCE(cc.relpages,0) AS relpages,  
    COALESCE(bs,0) AS bs,  
    COALESCE(CEIL((cc.reltuples*((datahdr+ma-  
      (CASE WHEN datahdr%ma=0 THEN ma ELSE datahdr%ma END))+nullhdr2+4))/(bs-20::float)),0) AS otta,  
    COALESCE(c2.relname,$$?$$) AS iname, COALESCE(c2.reltuples,0) AS ituples, COALESCE(c2.relpages,0) AS ipages,  
    COALESCE(CEIL((c2.reltuples*(datahdr-12))/(bs-20::float)),0) AS iotta -- very rough approximation, assumes all cols  
  FROM  
     pg_class cc  
  JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname <> $$information_schema$$  
  LEFT JOIN  
  (  
    SELECT  
      ma,bs,foo.nspname,foo.relname,  
      (datawidth+(hdr+ma-(case when hdr%ma=0 THEN ma ELSE hdr%ma END)))::numeric AS datahdr,  
      (maxfracsum*(nullhdr+ma-(case when nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2  
    FROM (  
      SELECT  
        ns.nspname, tbl.relname, hdr, ma, bs,  
        SUM((1-coalesce(null_frac,0))*coalesce(avg_width, 2048)) AS datawidth,  
        MAX(coalesce(null_frac,0)) AS maxfracsum,  
        hdr+(  
          SELECT 1+count(*)/8  
          FROM pg_stats s2  
          WHERE null_frac<>0 AND s2.schemaname = ns.nspname AND s2.tablename = tbl.relname  
        ) AS nullhdr  
      FROM pg_attribute att   
      JOIN pg_class tbl ON att.attrelid = tbl.oid  
      JOIN pg_namespace ns ON ns.oid = tbl.relnamespace   
      LEFT JOIN pg_stats s ON s.schemaname=ns.nspname  
      AND s.tablename = tbl.relname  
      AND s.inherited=false  
      AND s.attname=att.attname,  
      (  
        SELECT  
          (SELECT current_setting($$block_size$$)::numeric) AS bs,  
          CASE WHEN SUBSTRING(SPLIT_PART(v, $$ $$, 2) FROM $$#"[0-9]+.[0-9]+#"%$$ for $$#$$)  
            IN ($$8.0$$,$$8.1$$,$$8.2$$) THEN 27 ELSE 23 END AS hdr,  
          CASE WHEN v ~ $$mingw32$$ OR v ~ $$64-bit$$ THEN 8 ELSE 4 END AS ma  
        FROM (SELECT version() AS v) AS foo  
      ) AS constants  
      WHERE att.attnum > 0 AND tbl.relkind=$$r$$  
      GROUP BY 1,2,3,4,5  
    ) AS foo  
  ) AS rs  
  ON cc.relname = rs.relname AND nn.nspname = rs.nspname  
  LEFT JOIN pg_index i ON indrelid = cc.oid  
  LEFT JOIN pg_class c2 ON c2.oid = i.indexrelid  
) AS sml order by wastedbytes desc limit 5;
```

简化一下结构如下：

```sql
SELECT
  ...
FROM (
  SELECT
    ...
  FROM
    pg_class
  JOIN pg_namespace ON ...
  LEFT JOIN
  (
    SELECT
      ...
    FROM
      (
        SELECT
          ...
        FROM
          pg_attribute
        JOIN pg_class tbl ON ...
        JOIN pg_namespace ns ON ... 
        LEFT JOIN pg_stats
      )
  ) ON ...
  LEFT JOIN pg_index i ON ...
  LEFT JOIN pg_class c2 ON ...
) AS ...;
```



## 第一步拆(PART1)

```sql
        SELECT  
          (SELECT current_setting($$block_size$$)::numeric) AS bs,  
          CASE WHEN SUBSTRING(SPLIT_PART(v, $$ $$, 2) FROM $$#"[0-9]+.[0-9]+#"%$$ for $$#$$) 
            IN ($$8.0$$,$$8.1$$,$$8.2$$) THEN 27 ELSE 23 END AS hdr,  
          CASE WHEN v ~ $$mingw32$$ OR v ~ $$64-bit$$ THEN 8 ELSE 4 END AS ma  
        FROM (SELECT version() AS v) AS foo;
```

运行结果

```sql
  bs  | hdr | ma 
------+-----+----
 8192 |  23 |  8
(1 row)
```

*Q: hdr和ma是什么意思？？*



### 知识点

(1) `current_setting($$block_size$$)::numeric`

| 名称                                       | 返回类型 | 描述       |
| ---------------------------------------- | ---- | -------- |
| current_setting(setting_name[, missing_ok ]) | text | 获得设置的当前值 |

---

(2) `CASE WHEN ... THEN ... WHEN ... THEN ... ELSE ... END`

```sql
--简单Case函数
CASE sex
WHEN '1' THEN '男'
WHEN '2' THEN '女'
ELSE '其他' END

--Case搜索函数 
CASE WHEN sex = '1' THEN '男' 
WHEN sex = '2' THEN '女' 
ELSE '其他' END  

--两种方式，可以实现相同的功能。简单Case函数的写法相对比较简洁，但是和Case搜索函数相比，功能方面会有些限制，比如写判断式。还有一个需要注意的问题，Case函数只返回第一个符合条件的值，剩下的Case部分将会被自动忽略。
--比如说，下面这段SQL，你永远无法得到“第二类”这个结果 
CASE WHEN col_1 IN ( 'a', 'b') THEN '第一类' 
WHEN col_1 IN ('a')  THEN '第二类' 
ELSE'其他' END
```

---

(3) `SUBSTRING(SPLIT_PART(v, $$ $$, 2) FROM $$#"[0-9]+.[0-9]+#"%$$ for $$#$$)`

执行结果

```sql
postgres=# select SUBSTRING(SPLIT_PART(v, $$ $$, 2) FROM $$#"[0-9]+.[0-9]+#"%$$ for $$#$$) FROM (SELECT version() AS v) as foo;
 substring 
-----------
 10.3
 
postgres=# SELECT version();
 version                                                 
-----------
 PostgreSQL 10.3 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-28), 64-bit
 
```

先看下SPLIT_PART函数：`split_part(string text, delimiter text, field int) `按delimiter划分string并返回给定域（从1开始计算） 。

```sql
postgres=# select SPLIT_PART(v, $$ $$, 2) FROM (SELECT version() AS v) as foo;
 split_part 
------------
 10.3
```

再看下SUBSTRING函数：

`substring(string [from int] [for int]) `

```sql
postgres=# select SUBSTRING('10.3' FROM $$#"[0-9]+.[0-9]+#"%$$ for $$#$$);
 substring 
-----------
 10.3
```

（第一个参数肯定是"x.x"的形式去版本号，是否有必要用正则？）

**（现在用pg8.0 8.1 8.2版本的越来越少了，可以简化下）**

---

(4) `$$........$$`  

这个在手册的这里《4.1.2.4. 美元引用的字符串常量》：美元引用不是 SQL 标准的一部分，但是在书写复杂字符串文字方面，它常常是一种比兼容标准的单引号语法更方便的方法。当要表示的字符串常量位于其他常量中时它特别有用，这种情况常常在过程函数定义中出现。如果用单引号语法，上一个例子中的每个反斜线将必须被写成四个反斜线，这在解析原始字符串常量时会被缩减到两个反斜线，并且接着在函数执行期间重新解析内层字符串常量时变成一个。 

## 第二步拆(PART2)

```sql
SELECT  
        ns.nspname, tbl.relname, hdr, ma, bs,  
        SUM((1-coalesce(null_frac,0))*coalesce(avg_width, 2048)) AS datawidth,  
        MAX(coalesce(null_frac,0)) AS maxfracsum,  
        hdr+(  
          SELECT 1+count(*)/8  
          FROM pg_stats s2  
          WHERE null_frac<>0 AND s2.schemaname = ns.nspname AND s2.tablename = tbl.relname  
        ) AS nullhdr  
      FROM pg_attribute att   
      JOIN pg_class tbl ON att.attrelid = tbl.oid  
      JOIN pg_namespace ns ON ns.oid = tbl.relnamespace   
      LEFT JOIN pg_stats s ON s.schemaname=ns.nspname  
      AND s.tablename = tbl.relname  
      AND s.inherited=false  
      AND s.attname=att.attname,  
      (  
        SELECT  
          (SELECT current_setting($$block_size$$)::numeric) AS bs,  
          CASE WHEN SUBSTRING(SPLIT_PART(v, $$ $$, 2) FROM $$#"[0-9]+.[0-9]+#"%$$ for $$#$$)  
            IN ($$8.0$$,$$8.1$$,$$8.2$$) THEN 27 ELSE 23 END AS hdr,  
          CASE WHEN v ~ $$mingw32$$ OR v ~ $$64-bit$$ THEN 8 ELSE 4 END AS ma  
        FROM (SELECT version() AS v) AS foo  
      ) AS constants  
      WHERE att.attnum > 0 AND tbl.relkind=$$r$$  
      GROUP BY 1,2,3,4,5;
```

用PART1简化后（伪代码）

```sql
SELECT  
        ns.nspname, tbl.relname, hdr, ma, bs,  
        SUM((1-coalesce(null_frac,0))*coalesce(avg_width, 2048)) AS datawidth,  
        MAX(coalesce(null_frac,0)) AS maxfracsum,  
        hdr+(  
          SELECT 1+count(*)/8  
          FROM pg_stats s2  
          WHERE null_frac<>0 AND s2.schemaname = ns.nspname AND s2.tablename = tbl.relname  
        ) AS nullhdr
      FROM pg_attribute att
      JOIN pg_class tbl ON att.attrelid = tbl.oid  
      JOIN pg_namespace ns ON ns.oid = tbl.relnamespace   
      LEFT JOIN pg_stats s ON s.schemaname=ns.nspname  
      AND s.tablename = tbl.relname  
      AND s.inherited=false  
      AND s.attname=att.attname,  
      (  
        ...
        (PART1)
          bs  | hdr | ma 
        ------+-----+----
         8192 |  23 |  8
        (PART1)
        ...
      ) AS constants  
      WHERE att.attnum > 0 AND tbl.relkind=$$r$$  
      GROUP BY 1,2,3,4,5
```

### 知识点

(1) `coalesce`

COALESCE函数返回它的第一个非空参数的值。当且仅当所有参数都为空时才会返回空。它常用于在为显示目的检索数据时用缺省值替换空值。

---

(2)

```sql
hdr+(  
          SELECT 1+count(*)/8  
          FROM pg_stats s2  
          WHERE null_frac<>0 AND s2.schemaname = ns.nspname AND s2.tablename = tbl.relname  
        ) AS nullhdr
```

先说下这个hdr的定义：除了pg8.0 8.1 8.2三个版本，这个值都是23。

pg_stats表中的null_frac列的含义：列项中为空的比例。

**nullhdr  =   当前表有空值的列的数量/8 + 1 + 23**：当前表空值列的数目每超过8个，该值增加1（从24开始）

---

(3) 几个系统表的连接、过滤条件

总结下，pg_attribute根据表oid等信息挂上pg_class、pg_namespace、pg_stats的信息。提供给下面(4)聚合使用。具体见下面注释：

```sql
select * 
from pg_attribute att                        --所有表的列信息都在这里有一行
JOIN pg_class tbl ON att.attrelid = tbl.oid  --根据表的OID连接pg_class，取表名称、namespace、表类型
JOIN pg_namespace ns ON ns.oid = tbl.relnamespace  --按ns的oid连接pg_namespace，取ns的名称
LEFT JOIN pg_stats s ON s.schemaname=ns.nspname    --四个条件左连pg_stats
      AND s.tablename = tbl.relname  
      AND s.inherited=false  
      AND s.attname=att.attname
WHERE att.attnum > 0 AND tbl.relkind=$$r$$;    --列编号大于0，表示非系统列。
                                               --元素类型为表
```

---

(4)  聚合列

`SUM((1-coalesce(null_frac,0))*coalesce(avg_width, 2048)) AS datawidth, `

- 注意这里可以简化为按每张表的所有列进行聚合。
- null_frac是pg_stats视图列（pg_stats每一行代表表的一列）：列项中为空的比例。



\>>>>> SUM((1-coalesce(null_frac,0))*coalesce(avg_width, 2048)) \<<<<<

**求和：表的一列有数据的比例 * 列项的平均字节宽度 = 该表一行平均数据宽度**

(注意这里求和的每一个子项都是当前表的一列)

`MAX(coalesce(null_frac,0)) AS maxfracsum`

当前表所有类中，最大的那个null_frac（列项中为空的比例 ）

---

(5) 聚合

按` nspname | relname | hdr | ma | bs`五列进行聚合，`hdr | ma | bs`这三个值不变的话，可以看成按ns和relname聚合，每张表占一行。

```sql
      nspname       |         relname         | hdr | ma |  bs  |    datawidth     | maxfracsum | nullhdr 
--------------------+-------------------------+-----+----+------+------------------+------------+---------
 information_schema | sql_features            |  23 |  8 | 8192 |               47 |          1 |      24
 information_schema | sql_implementation_info |  23 |  8 | 8192 | 40.0833334624767 |   0.583333 |      24
 information_schema | sql_languages           |  23 |  8 | 8192 |               28 |          1 |      24
 information_schema | sql_packages            |  23 |  8 | 8192 |               29 |          1 |      24
 information_schema | sql_parts               |  23 |  8 | 8192 |               44 |          1 |      24
 information_schema | sql_sizing              |  23 |  8 | 8192 | 52.1304358839989 |   0.608696 |      24
 information_schema | sql_sizing_profiles     |  23 |  8 | 8192 |            10240 |          0 |      24
 pg_catalog         | pg_aggregate            |  23 |  8 | 8192 | 63.3260869383812 |   0.949275 |      24
 pg_catalog         | pg_am                   |  23 |  8 | 8192 |               69 |          0 |      24
 pg_catalog         | pg_amop                 |  23 |  8 | 8192 |               27 |          0 |      24
 pg_catalog         | pg_amproc               |  23 |  8 | 8192 |               18 |          0 |      24
 pg_catalog         | pg_attrdef              |  23 |  8 | 8192 |             8192 |          0 |      24

...
```

### 总结

(PART2)连接几张系统表，主要是使用pg_stats的数据计算了每张表的平均数据宽度和非空列的最大的列项为空的比例。

## 第三步拆(PART3)

```sql
SELECT  
      ma,bs,foo.nspname,foo.relname,  
      (datawidth+(hdr+ma-(case when hdr%ma=0 THEN ma ELSE hdr%ma END)))::numeric AS datahdr,  
      (maxfracsum*(nullhdr+ma-(case when nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2  
    FROM (  
      SELECT  
        ns.nspname, tbl.relname, hdr, ma, bs,  
        SUM((1-coalesce(null_frac,0))*coalesce(avg_width, 2048)) AS datawidth,  
        MAX(coalesce(null_frac,0)) AS maxfracsum,  
        hdr+(  
          SELECT 1+count(*)/8  
          FROM pg_stats s2  
          WHERE null_frac<>0 AND s2.schemaname = ns.nspname AND s2.tablename = tbl.relname  
        ) AS nullhdr  
      FROM pg_attribute att   
      JOIN pg_class tbl ON att.attrelid = tbl.oid  
      JOIN pg_namespace ns ON ns.oid = tbl.relnamespace   
      LEFT JOIN pg_stats s ON s.schemaname=ns.nspname  
      AND s.tablename = tbl.relname  
      AND s.inherited=false  
      AND s.attname=att.attname,  
      (  
        SELECT  
          (SELECT current_setting($$block_size$$)::numeric) AS bs,  
          CASE WHEN SUBSTRING(SPLIT_PART(v, $$ $$, 2) FROM $$#"[0-9]+.[0-9]+#"%$$ for $$#$$)  
            IN ($$8.0$$,$$8.1$$,$$8.2$$) THEN 27 ELSE 23 END AS hdr,  
          CASE WHEN v ~ $$mingw32$$ OR v ~ $$64-bit$$ THEN 8 ELSE 4 END AS ma  
        FROM (SELECT version() AS v) AS foo  
      ) AS constants  
      WHERE att.attnum > 0 AND tbl.relkind=$$r$$  
      GROUP BY 1,2,3,4,5  
    ) AS foo;
```

使用PART2化简（伪代码）：

```sql
SELECT  
      ma,bs,foo.nspname,foo.relname,  
      (datawidth+(hdr+ma-(case when hdr%ma=0 THEN ma ELSE hdr%ma END)))::numeric AS datahdr,  
      (maxfracsum*(nullhdr+ma-(case when nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2 
    FROM (  
      ...
      (PART2)
      ...
    ) AS foo;
```

### 总结

`(datawidth+(hdr+ma-(case when hdr%ma=0 THEN ma ELSE hdr%ma END)))::numeric`

数据平均宽度+23+8-7

*Q: 计算结果代表什么？*



`(maxfracsum*(nullhdr+ma-(case when nullhdr%ma=0 THEN ma ELSE nullhdr%ma END)))`

*Q: 计算结果代表什么？*



## 第四步化简原始SQL

```sql
SELECT  
  current_database() AS db, schemaname, tablename, reltuples::bigint AS tups, relpages::bigint AS pages, otta,  
  ROUND(CASE WHEN otta=0 OR sml.relpages=0 OR sml.relpages=otta THEN 0.0 ELSE sml.relpages/otta::numeric END,1) AS tbloat,  
  CASE WHEN relpages < otta THEN 0 ELSE relpages::bigint - otta END AS wastedpages,  
  CASE WHEN relpages < otta THEN 0 ELSE bs*(sml.relpages-otta)::bigint END AS wastedbytes,  
  CASE WHEN relpages < otta THEN $$0 bytes$$::text ELSE (bs*(relpages-otta))::bigint || $$ bytes$$ END AS wastedsize,  
  iname, ituples::bigint AS itups, ipages::bigint AS ipages, iotta,  
  ROUND(CASE WHEN iotta=0 OR ipages=0 OR ipages=iotta THEN 0.0 ELSE ipages/iotta::numeric END,1) AS ibloat,  
  CASE WHEN ipages < iotta THEN 0 ELSE ipages::bigint - iotta END AS wastedipages,  
  CASE WHEN ipages < iotta THEN 0 ELSE bs*(ipages-iotta) END AS wastedibytes,  
  CASE WHEN ipages < iotta THEN $$0 bytes$$ ELSE (bs*(ipages-iotta))::bigint || $$ bytes$$ END AS wastedisize,  
  CASE WHEN relpages < otta THEN  
    CASE WHEN ipages < iotta THEN 0 ELSE bs*(ipages-iotta::bigint) END  
    ELSE CASE WHEN ipages < iotta THEN bs*(relpages-otta::bigint)  
      ELSE bs*(relpages-otta::bigint + ipages-iotta::bigint) END  
  END AS totalwastedbytes  
FROM (  
  SELECT  
    nn.nspname AS schemaname,  
    cc.relname AS tablename,  
    COALESCE(cc.reltuples,0) AS reltuples,  
    COALESCE(cc.relpages,0) AS relpages,  
    COALESCE(bs,0) AS bs,  
    COALESCE(CEIL((cc.reltuples*((datahdr+ma-  
      (CASE WHEN datahdr%ma=0 THEN ma ELSE datahdr%ma END))+nullhdr2+4))/(bs-20::float)),0) AS otta,  
    COALESCE(c2.relname,$$?$$) AS iname, COALESCE(c2.reltuples,0) AS ituples, COALESCE(c2.relpages,0) AS ipages,  
    COALESCE(CEIL((c2.reltuples*(datahdr-12))/(bs-20::float)),0) AS iotta -- very rough approximation, assumes all cols  
  FROM  
     pg_class cc  
  JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname <> $$information_schema$$  
  LEFT JOIN  
  (  
    ...
    (PART3)
    ...
  ) AS rs  
  ON cc.relname = rs.relname AND nn.nspname = rs.nspname  
  LEFT JOIN pg_index i ON indrelid = cc.oid  
  LEFT JOIN pg_class c2 ON c2.oid = i.indexrelid  
) AS sml order by wastedbytes desc limit 5;
```

## 第五步遇到阻塞问题

后面分析需要先解决 hdr 和 ma 的问题：

```
SELECT  
          (SELECT current_setting($$block_size$$)::numeric) AS bs,  
          CASE WHEN SUBSTRING(SPLIT_PART(v, $$ $$, 2) FROM $$#"[0-9]+.[0-9]+#"%$$ for $$#$$) 
            IN ($$8.0$$,$$8.1$$,$$8.2$$) THEN 27 ELSE 23 END AS hdr,  
          CASE WHEN v ~ $$mingw32$$ OR v ~ $$64-bit$$ THEN 8 ELSE 4 END AS ma  
        FROM (SELECT version() AS v) AS foo;

  bs  | hdr | ma 
------+-----+----
 8192 |  23 |  8
(1 row)      
```

这里hdr和ma是什么意思？





##（未解决）

## 第六步解决问题后继续拆(PART4)

使用PART3化简原始SQL后，取出PART4：

```
  SELECT  
    nn.nspname AS schemaname,  
    cc.relname AS tablename,  
    COALESCE(cc.reltuples,0) AS reltuples,  
    COALESCE(cc.relpages,0) AS relpages,  
    COALESCE(bs,0) AS bs,  
    COALESCE(CEIL((cc.reltuples*((datahdr+ma-  
      (CASE WHEN datahdr%ma=0 THEN ma ELSE datahdr%ma END))+nullhdr2+4))/(bs-20::float)),0) AS otta,  
    COALESCE(c2.relname,$$?$$) AS iname, COALESCE(c2.reltuples,0) AS ituples, COALESCE(c2.relpages,0) AS ipages,  
    COALESCE(CEIL((c2.reltuples*(datahdr-12))/(bs-20::float)),0) AS iotta -- very rough approximation, assumes all cols  
  FROM  
     pg_class cc  
  JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname <> $$information_schema$$  
  LEFT JOIN  
  (  
    ...
    (PART3)
    ...
  ) AS rs  
  ON cc.relname = rs.relname AND nn.nspname = rs.nspname  
  LEFT JOIN pg_index i ON indrelid = cc.oid  
  LEFT JOIN pg_class c2 ON c2.oid = i.indexrelid  
```

