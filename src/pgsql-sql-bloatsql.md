# 拆解分析德哥给出的表膨胀检测SQL

> 高铭杰  20180625  jackgo73@outlook.com

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



## (PART1)

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

### 知识点

`current_setting($$block_size$$)::numeric`

| 名称                                       | 返回类型 | 描述       |
| ---------------------------------------- | ---- | -------- |
| current_setting(setting_name[, missing_ok ]) | text | 获得设置的当前值 |

---

`CASE WHEN ... THEN ... WHEN ... THEN ... ELSE ... END`

```
简单Case函数
CASE sex
WHEN '1' THEN '男'
WHEN '2' THEN '女'
ELSE '其他' END

--Case搜索函数 
CASE WHEN sex = '1' THEN '男' 
WHEN sex = '2' THEN '女' 
ELSE '其他' END  
   种方式，可以实现相同的功能。简单Case函数的写法相对比较简洁，但是和Case搜索函数相比，功能方面会有些限制，比如写判断式。还有一个需要注意的问题，Case函数只返回第一个符合条件的值，剩下的Case部分将会被自动忽略。
--比如说，下面这段SQL，你永远无法得到“第二类”这个结果 
CASE WHEN col_1 IN ( 'a', 'b') THEN '第一类' 
WHEN col_1 IN ('a')  THEN '第二类' 
ELSE'其他' END
```

---

`SUBSTRING(SPLIT_PART(v, $$ $$, 2) FROM $$#"[0-9]+.[0-9]+#"%$$ for $$#$$)`

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

---

`$$........$$`  

这个在手册的这里《4.1.2.4. 美元引用的字符串常量 》：美元引用不是 SQL 标准的一部分，但是在书写复杂字符串文字方面，它常常是一种比兼容标准的单引号语法更方便的方法。当要表示的字符串常量位于其他常量中时它特别有用，这种情况常常在过程函数定义中出现。如果用单引号语法，上一个例子中的每个反斜线将必须被写成四个反斜线，这在解析原始字符串常量时会被缩减到两个反斜线，并且接着在函数执行期间重新解析内层字符串常量时变成一个。 

## (PART2)

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
      GROUP BY 1,2,3,4,5
```

用PART1简化后

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







