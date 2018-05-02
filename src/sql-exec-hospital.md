# The Hospital案例——执行计划&成本分析（未完）

gaomingjie

2018-05-02

https://en.wikibooks.org/wiki/SQL_Exercises/The_Hospital

![](images/sql-exec-hospital-1.png)

## 背景

在The Hospital案例中，尝试做几种SQL执行计划的分析和成本计算。

PostgreSQL 9.6.8相关参数：

```
#seq_page_cost = 1.0                    # measured on an arbitrary scale
#random_page_cost = 4.0                 # same scale as above
#cpu_tuple_cost = 0.01                  # same scale as above
#cpu_index_tuple_cost = 0.005           # same scale as above
#cpu_operator_cost = 0.0025             # same scale as above
#parallel_tuple_cost = 0.1              # same scale as above
#parallel_setup_cost = 1000.0   # same scale as above
#min_parallel_relation_size = 8MB
#effective_cache_size = 4GB
```

## 构造数据
