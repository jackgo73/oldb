# Postgresql 执行计划&索引相关

> JackGao
>
> Email: jackgo73@outlook.com
>
> Date:  20180420

## 背景

从基础、用实例开始学习执行计划、索引、优化



## 测试1 explain相关

- 有一点很重要：一个上层结点的开销包括它的所有子结点的开销 
- 这个开销只反映规划器关心的东西。特别是这个开销没有考虑结果行传递给客户端所花费的时间，这个时间可能是实际花费时间中的一个重要因素；但是它被规划器忽略了，因为它无法通过修改计划来改变（我们相信，每个正确的计划都将输出同样的行集） 
- 行数值有一些小技巧，因为它不是计划结点处理或扫描过的行数，而是该结点发出的行数。这通常比被扫描的行数少一些， 因为有些被扫描的行会被应用于此结点上的任意WHERE子句条件过滤掉。 理想中顶层的行估计会接近于查询实际返回、更新、删除的行数。 

```sql
create table tenk1 (unique1 int, random int, info text);
insert into tenk1 select generate_series(1,10000),(random()*1000)::int,(random()::text);

explain select * from tenk1;
                         QUERY PLAN                         
------------------------------------------------------------
 Seq Scan on tenk1  (cost=0.00..174.00 rows=10000 width=26)
(1 row)

-- 0.00估计的启动开销。在输出阶段可以开始之前消耗的时间，例如在一个排序结点里执行排序的时间
-- 174.00估计的总开销。这个估计值基于的假设是计划结点会被运行到完成，即所有可用的行都被检索。不过实际上一个结点的父结点可能很快停止读所有可用的行
-- rows=10000 这个计划结点输出行数的估计值。同样，也假定该结点能运行到完成
-- width=26 预计这个计划结点输出的行平均宽度（以字节计算）
```

- 开销计算 ：tenk1有358个 磁 盘 页 面 和10000行 。 开 销 被 计 算 为 
- （ 页面读取数\*seq_page_cost）+（ 扫 描 的 行 数\*cpu_tuple_cost） 
- 默 认 情 况下，seq_page_cost是1.0，cpu_tuple_cost是0.01
- 因此估计的开销是 (74* 1.0) + (10000 * 0.01) = 174

```sql
SELECT relpages, reltuples FROM pg_class WHERE relname = 'tenk1';
 relpages | reltuples 
----------+-----------
       74 |     10000

-- relpages:该表磁盘表示的尺寸，以页面计（页面尺寸为BLCKSZ）。这只是一个由规划器使用的估计值。它被VACUUM、ANALYZE以及一些DDL命令（如CREATE INDEX）所更新。
```

现在让我们修改查询并增加一个WHERE条件 

```
EXPLAIN SELECT * FROM tenk1 WHERE unique1 < 7000;
                        QUERY PLAN                         
-----------------------------------------------------------
 Seq Scan on tenk1  (cost=0.00..199.00 rows=7000 width=26)
   Filter: (unique1 < 7000)
(2 rows)
```

