# 'Planet Express案例'执行计划&成本分析

gao

2018-4-28

https://en.wikibooks.org/wiki/SQL_Exercises/Planet_Express

![](images/sql-exec-hospital-0.png)

## 背景

在planet express案例中，做几种SQL执行计划的分析和成本计算。

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

```sql
 DROP TABLE Employee, Planet, Shipment, Has_Clearance,  Client, Package;
 CREATE TABLE Employee (
   EmployeeID INTEGER PRIMARY KEY NOT NULL,
   Name TEXT NOT NULL,
   Position TEXT NOT NULL,
   Salary REAL NOT NULL,
   Remarks TEXT
 );
 
 CREATE TABLE Planet (
   PlanetID INTEGER PRIMARY KEY NOT NULL,
   Name TEXT NOT NULL,
   Coordinates REAL NOT NULL
 );
 
 CREATE TABLE Shipment (
   ShipmentID INTEGER PRIMARY KEY NOT NULL,
   Date TEXT,
   Manager INTEGER NOT NULL
     CONSTRAINT fk_Employee_EmployeeID REFERENCES Employee(EmployeeID),
   Planet INTEGER NOT NULL
     CONSTRAINT fk_Planet_PlanetID REFERENCES Planet(PlanetID)
 );
 
 CREATE TABLE Has_Clearance (
   Employee INTEGER NOT NULL
     CONSTRAINT fk_Employee_EmployeeID REFERENCES Employee(EmployeeID),
   Planet INTEGER NOT NULL
     CONSTRAINT fk_Planet_PlanetID REFERENCES Planet(PlanetID),
   Level INTEGER NOT NULL,
   PRIMARY KEY(Employee, Planet)
 );
 
 CREATE TABLE Client (
   AccountNumber INTEGER PRIMARY KEY NOT NULL,
   Name TEXT NOT NULL
 );
 
 CREATE TABLE Package (
   Shipment INTEGER NOT NULL
     CONSTRAINT fk_Shipment_ShipmentID REFERENCES Shipment(ShipmentID),
   PackageNumber INTEGER NOT NULL,
   Contents TEXT NOT NULL,
   Weight REAL NOT NULL,
   Sender INTEGER NOT NULL
     CONSTRAINT fk_Client_AccountNumber1 REFERENCES Client(AccountNumber),
   Recipient INTEGER NOT NULL
     CONSTRAINT fk_Client_AccountNumber2 REFERENCES Client(AccountNumber),
   PRIMARY KEY(Shipment, PackageNumber)
 );
 
INSERT INTO Client VALUES(1, 'Zapp Brannigan');
INSERT INTO Client VALUES(2, 'Al Gore''s Head');
INSERT INTO Client VALUES(3, 'Barbados Slim');
INSERT INTO Client VALUES(4, 'Ogden Wernstrom');
INSERT INTO Client VALUES(5, 'Leo Wong');
INSERT INTO Client VALUES(6, 'Lrrr');
INSERT INTO Client VALUES(7, 'John Zoidberg');
INSERT INTO Client VALUES(8, 'John Zoidfarb');
INSERT INTO Client VALUES(9, 'Morbo');
INSERT INTO Client VALUES(10, 'Judge John Whitey');
INSERT INTO Client VALUES(11, 'Calculon');
INSERT INTO Employee VALUES(1, 'Phillip J. Fry', 'Delivery boy', 7500.0, 'Not to be confused with the Philip J. Fry from Hovering Squid World 97a');
INSERT INTO Employee VALUES(2, 'Turanga Leela', 'Captain', 10000.0, NULL);
INSERT INTO Employee VALUES(3, 'Bender Bending Rodriguez', 'Robot', 7500.0, NULL);
INSERT INTO Employee VALUES(4, 'Hubert J. Farnsworth', 'CEO', 20000.0, NULL);
INSERT INTO Employee VALUES(5, 'John A. Zoidberg', 'Physician', 25.0, NULL);
INSERT INTO Employee VALUES(6, 'Amy Wong', 'Intern', 5000.0, NULL);
INSERT INTO Employee VALUES(7, 'Hermes Conrad', 'Bureaucrat', 10000.0, NULL);
INSERT INTO Employee VALUES(8, 'Scruffy Scruffington', 'Janitor', 5000.0, NULL);
INSERT INTO Planet VALUES(1, 'Omicron Persei 8', 89475345.3545);
INSERT INTO Planet VALUES(2, 'Decapod X', 65498463216.3466);
INSERT INTO Planet VALUES(3, 'Mars', 32435021.65468);
INSERT INTO Planet VALUES(4, 'Omega III', 98432121.5464);
INSERT INTO Planet VALUES(5, 'Tarantulon VI', 849842198.354654);
INSERT INTO Planet VALUES(6, 'Cannibalon', 654321987.21654);
INSERT INTO Planet VALUES(7, 'DogDoo VII', 65498721354.688);
INSERT INTO Planet VALUES(8, 'Nintenduu 64', 6543219894.1654);
INSERT INTO Planet VALUES(9, 'Amazonia', 65432135979.6547);
INSERT INTO Has_Clearance VALUES(1, 1, 2);
INSERT INTO Has_Clearance VALUES(1, 2, 3);
INSERT INTO Has_Clearance VALUES(2, 3, 2);
INSERT INTO Has_Clearance VALUES(2, 4, 4);
INSERT INTO Has_Clearance VALUES(3, 5, 2);
INSERT INTO Has_Clearance VALUES(3, 6, 4);
INSERT INTO Has_Clearance VALUES(4, 7, 1);
INSERT INTO Shipment VALUES(1, '3004/05/11', 1, 1);
INSERT INTO Shipment VALUES(2, '3004/05/11', 1, 2);
INSERT INTO Shipment VALUES(3, NULL, 2, 3);
INSERT INTO Shipment VALUES(4, NULL, 2, 4);
INSERT INTO Shipment VALUES(5, NULL, 7, 5);
INSERT INTO Package VALUES(1, 1, 'Undeclared', 1.5, 1, 2);
INSERT INTO Package VALUES(2, 1, 'Undeclared', 10.0, 2, 3);
INSERT INTO Package VALUES(2, 2, 'A bucket of krill', 2.0, 8, 7);
INSERT INTO Package VALUES(3, 1, 'Undeclared', 15.0, 3, 4);
INSERT INTO Package VALUES(3, 2, 'Undeclared', 3.0, 5, 1);
INSERT INTO Package VALUES(3, 3, 'Undeclared', 7.0, 2, 3);
INSERT INTO Package VALUES(4, 1, 'Undeclared', 5.0, 4, 5);
INSERT INTO Package VALUES(4, 2, 'Undeclared', 27.0, 1, 2);
INSERT INTO Package VALUES(5, 1, 'Undeclared', 100.0, 5, 1);
```

## 问题1：Which pilots transported those packages?

收到了1.5Kg包裹的那个人，发了一些包裹。问这些包裹都是哪位飞行员运送的？	

### SQL

```sql
postgres=# select e.name from employee e join shipment s on e.employeeid=s.manager join package p on s.shipmentid=p.shipment where p.shipment in (select p.shipment from client c join package as p on c.accountnumber=p.sender where c.accountnumber=(select c.accountnumber from client c join package p on c.accountnumber=p.recipient where p.weight=1.5)) group by e.name;
      name      
----------------
 Phillip J. Fry
 Turanga Leela
(2 rows)


SQL：

select e.name 
from employee e 
  join shipment s on e.employeeid=s.manager 
  join package p on s.shipmentid=p.shipment 
where p.shipment in (
  select p.shipment 
  from client c 
    join package as p 
    on c.accountnumber=p.sender 
  where c.accountnumber=(
    select c.accountnumber 
    from client c 
      join package p 
      on c.accountnumber=p.recipient 
    where p.weight=1.5)) 
group by e.name;
```

### 执行计划

```sql
postgres=# explain (analyze,verbose,buffers,timing,costs) select e.name from employee e join shipment s on e.employeeid=s.manager join package p on s.shipmentid=p.shipment where p.shipment in (select p.shipment from client c join package as p on c.accountnumber=p.sender where c.accountnumber=(select c.accountnumber from client c join package p on c.accountnumber=p.recipient where p.weight=1.5)) group by e.name;
                                                                          QUERY PLAN                                                                           
---------------------------------------------------------------------------------------------------------------------------------------------------------------
 Group  (cost=21.57..21.57 rows=1 width=32) (actual time=0.156..0.159 rows=2 loops=1)
   Output: e.name
   Group Key: e.name
   Buffers: shared hit=22
   InitPlan 1 (returns $0)
     ->  Hash Join  (cost=1.12..2.29 rows=1 width=4) (actual time=0.034..0.038 rows=1 loops=1)
           Output: c_1.accountnumber
           Hash Cond: (c_1.accountnumber = p_2.recipient)
           Buffers: shared hit=2
           ->  Seq Scan on public.client c_1  (cost=0.00..1.11 rows=11 width=4) (actual time=0.002..0.004 rows=11 loops=1)
                 Output: c_1.accountnumber, c_1.name
                 Buffers: shared hit=1
           ->  Hash  (cost=1.11..1.11 rows=1 width=4) (actual time=0.018..0.018 rows=1 loops=1)
                 Output: p_2.recipient
                 Buckets: 1024  Batches: 1  Memory Usage: 9kB
                 Buffers: shared hit=1
                 ->  Seq Scan on public.package p_2  (cost=0.00..1.11 rows=1 width=4) (actual time=0.010..0.014 rows=1 loops=1)
                       Output: p_2.recipient
                       Filter: (p_2.weight = '1.5'::double precision)
                       Rows Removed by Filter: 8
                       Buffers: shared hit=1
   ->  Sort  (cost=19.28..19.29 rows=1 width=32) (actual time=0.249..0.252 rows=5 loops=1)
         Output: e.name
         Sort Key: e.name
         Sort Method: quicksort  Memory: 25kB
         Buffers: shared hit=22
         ->  Nested Loop  (cost=2.72..19.27 rows=1 width=32) (actual time=0.159..0.207 rows=5 loops=1)
               Output: e.name
               Buffers: shared hit=22
               ->  Nested Loop  (cost=2.57..19.05 rows=1 width=4) (actual time=0.149..0.171 rows=5 loops=1)
                     Output: s.manager
                     Buffers: shared hit=12
                     ->  Nested Loop  (cost=2.43..18.65 rows=2 width=12) (actual time=0.136..0.147 rows=2 loops=1)
                           Output: s.manager, s.shipmentid, p_1.shipment
                           Buffers: shared hit=8
                           ->  Unique  (cost=2.28..2.29 rows=2 width=4) (actual time=0.118..0.121 rows=2 loops=1)
                                 Output: p_1.shipment
                                 Buffers: shared hit=4
                                 ->  Sort  (cost=2.28..2.28 rows=2 width=4) (actual time=0.117..0.118 rows=2 loops=1)
                                       Output: p_1.shipment
                                       Sort Key: p_1.shipment
                                       Sort Method: quicksort  Memory: 25kB
                                       Buffers: shared hit=4
                                       ->  Nested Loop  (cost=0.00..2.27 rows=2 width=4) (actual time=0.090..0.098 rows=2 loops=1)
                                             Output: p_1.shipment
                                             Buffers: shared hit=4
                                             ->  Seq Scan on public.client c  (cost=0.00..1.14 rows=1 width=4) (actual time=0.081..0.084 rows=1 loops=1)
                                                   Output: c.accountnumber, c.name
                                                   Filter: (c.accountnumber = $0)
                                                   Rows Removed by Filter: 10
                                                   Buffers: shared hit=3
                                             ->  Seq Scan on public.package p_1  (cost=0.00..1.11 rows=2 width=8) (actual time=0.006..0.010 rows=2 loops=1)
                                                   Output: p_1.shipment, p_1.packagenumber, p_1.contents, p_1.weight, p_1.sender, p_1.recipient
                                                   Filter: (p_1.sender = $0)
                                                   Rows Removed by Filter: 7
                                                   Buffers: shared hit=1
                           ->  Index Scan using shipment_pkey on public.shipment s  (cost=0.15..8.17 rows=1 width=8) (actual time=0.009..0.009 rows=1 loops=2)
                                 Output: s.shipmentid, s.date, s.manager, s.planet
                                 Index Cond: (s.shipmentid = p_1.shipment)
                                 Buffers: shared hit=4
                     ->  Index Only Scan using package_pkey on public.package p  (cost=0.14..0.18 rows=2 width=4) (actual time=0.006..0.009 rows=2 loops=2)
                           Output: p.shipment, p.packagenumber
                           Index Cond: (p.shipment = s.shipmentid)
                           Heap Fetches: 5
                           Buffers: shared hit=4
               ->  Index Scan using employee_pkey on public.employee e  (cost=0.15..0.21 rows=1 width=36) (actual time=0.004..0.005 rows=1 loops=5)
                     Output: e.employeeid, e.name, e."position", e.salary, e.remarks
                     Index Cond: (e.employeeid = s.manager)
                     Buffers: shared hit=10
 Planning time: 1.732 ms
 Execution time: 0.595 ms
(71 rows)                          
```

### 化简（便于分析）

```sql
化简SQL：
select e.name 
from employee e 
  join shipment s on e.employeeid=s.manager 
  join package p on s.shipmentid=p.shipment 
where p.shipment in (
  select p.shipment 
  from client c 
    join package as p 
    on c.accountnumber=p.sender 
  where c.accountnumber=(
    select c.accountnumber 
    from client c 
      join package p 
      on c.accountnumber=p.recipient 
    where p.weight=1.5)) 
group by e.name;

化简计划：
Group  (cost=21.57..21.57 rows=1 width=32) 
     ->  Hash Join 
           ->  Seq Scan on public.client c_1
           ->  Hash
                 ->  Seq Scan on public.package p_2
   ->  Sort
         ->  Nested Loop
               ->  Nested Loop
                     ->  Nested Loop
                           ->  Unique
                                 ->  Sort
                                       ->  Nested Loop
                                             ->  Seq Scan on public.client c 
                                             ->  Seq Scan on public.package p_1 
                           ->  Index Scan using shipment_pkey on public.shipment s 
                     ->  Index Only Scan using package_pkey on public.package p  
               ->  Index Scan using employee_pkey on public.employee e
------------------------------------------------------
```

#### 分析：（0）——>（1）

```sql
化简计划：
Group  (cost=21.57..21.57 rows=1 width=32) 
------------------------------------------------------
（0）计算最下面的使用weight=1.5的子查询，使用hash连接最后给出accountnumber
     ->  Hash Join 
           ->  Seq Scan on public.client c_1
           ->  Hash
                 ->  Seq Scan on public.package p_2
------------------------------------------------------
   ->  Sort
         ->  Nested Loop
               ->  Nested Loop
                     ->  Nested Loop
                           ->  Unique
                                 ->  Sort
------------------------------------------------------
（1）这个循环嵌套连接正在计算第二个子查询，根据（0）给出的accountnumber作为条件，查询符合的shipment，这里使用循环嵌套连接，外表过滤后剩1行内标循环1次，匹配上了两个数据，所以rows=2
                                       ->  Nested Loop
                                             ->  Seq Scan on public.client c (cost=0.00..1.14 rows=1 width=4)
                                             ->  Seq Scan on public.package p_1 (cost=0.00..1.11 rows=2 width=8)
------------------------------------------------------
                           ->  Index Scan using shipment_pkey on public.shipment s 
                     ->  Index Only Scan using package_pkey on public.package p  
               ->  Index Scan using employee_pkey on public.employee e
```

至此，SQL和执行计划可以化简为（伪代码）：

#### 继续分析（2）-——>（3）

```sql
化简SQL：
select e.name 
from employee e 
  join shipment s on e.employeeid=s.manager 
  join package p on s.shipmentid=p.shipment 
where p.shipment in (2,3) 
group by e.name;

化简计划：
Group  (cost=21.57..21.57 rows=1 width=32) 
   ->  Sort
         ->  Nested Loop
（3）这个循环嵌套以（2）的结果为外表，这个表中有s表的符合条件的元组，每条需要在e表中扫描一遍，所以索引扫描做了5遍loops=5。
               ->  Nested Loop
------------------------------------------------------
（2）IN的排序去重之后，得到(2,3)。然后使用循环嵌套连接进行匹配，分别使用2和3在shipment表中进行匹配，所以可以看到index Scan实际上循环了两次。至此，可以得到所有满足p.shipment in (2,3)条件的s表中的行。
                     ->  Nested Loop
                           ->  Unique
                                 ->  Sort
                                       ->  Nested Loop返回数据(2,3)
                           ->  Index Scan using shipment_pkey on public.shipment s (actual time=0.009..0.009 rows=1 loops=2)
                           Index Cond: (s.shipmentid = p_1.shipment)
                     ->  Index Only Scan using package_pkey on public.package p  
------------------------------------------------------
               ->  Index Scan using employee_pkey on public.employee e (actual time=0.004..0.005 rows=1 loops=5)
```

至此，SQL和执行计划可以化简为（伪代码）：

#### 继续分析（4）

```sql
化简SQL：
select e.name 
from （五条数据： Phillip J. Fry、Phillip J. Fry、Turanga Leela、Turanga Leela、Turanga Leela）
group by e.name;


化简计划：
Group  (cost=21.57..21.57 rows=1 width=32) 
（4）Groupby前进行排序
   ->  Sort
       （五条数据： Phillip J. Fry、Phillip J. Fry、Turanga Leela、Turanga Leela、Turanga Leela）
```

#### 最终输出

```sql
select e.name 
from （五条数据： Phillip J. Fry、Phillip J. Fry、Turanga Leela、Turanga Leela、Turanga Leela）
group by e.name;

      name      
----------------
 Phillip J. Fry
 Turanga Leela
(2 rows)
```

## 问题2：Who received a 1.5kg package?

### SQL

```sql
postgres=# select name from client c left join package p on c.accountnumber=recipient where p.weight=1.5;
      name      
----------------
 Al Gore s Head
(1 row)

postgres=# select relpages,reltuples from pg_class where relname='client';
 relpages | reltuples 
----------+-----------
        1 |        11
(1 row)

postgres=# select relpages,reltuples from pg_class where relname='package';
 relpages | reltuples 
----------+-----------
        1 |         9
(1 row)
```
### 执行计划——hash join

```sql
postgres=# explain (analyze,verbose,buffers,timing,costs) select name from client c left join package p on c.accountnumber=recipient where p.weight=1.5;
                                                      QUERY PLAN                                                      
----------------------------------------------------------------------------------------------------------------------
 Hash Join  (cost=1.12..2.29 rows=1 width=12) (actual time=0.039..0.045 rows=1 loops=1)
   Output: c.name
   Hash Cond: (c.accountnumber = p.recipient)
   Buffers: shared hit=2
   ->  Seq Scan on public.client c  (cost=0.00..1.11 rows=11 width=16) (actual time=0.010..0.012 rows=11 loops=1)
         Output: c.accountnumber, c.name
         Buffers: shared hit=1
   ->  Hash  (cost=1.11..1.11 rows=1 width=4) (actual time=0.017..0.017 rows=1 loops=1)
         Output: p.recipient
         Buckets: 1024  Batches: 1  Memory Usage: 9kB
         Buffers: shared hit=1
         ->  Seq Scan on public.package p  (cost=0.00..1.11 rows=1 width=4) (actual time=0.008..0.013 rows=1 loops=1)
               Output: p.recipient
               Filter: (p.weight = '1.5'::double precision)
               Rows Removed by Filter: 8
               Buffers: shared hit=1
 Planning time: 0.415 ms
 Execution time: 0.095 ms
(18 rows)
```

首先内(右)表扫描加载到内存HASH表, hash key为JOIN列，然后外(左)表扫描, 并与内存中的HASH表进行关联, 输出最终结果。

1. Hash的内层节点Seq Scan首先对表package做seq scan为构建哈希表提供数据。

   `Seq Scan on public.package p  (cost=0.00..1.11 rows=1 width=4)`。

   注意这里面把条件weight=1.5下推到这个节点了，

   成本计算：

   `seq_page_cost * p.relpages + cpu_tuple_cost * p.reltuples + 等号操作符的cost = 1 * 1 + 9 * 0.01 + cost('=') = 1.11`

2. Hash节点开始构建哈希表。

   `Buckets: 1024  Batches: 1  Memory Usage: 9kB`

   成本计算：成本很小没有体现，直接继承子节点的成本1.11。

3. 有了Hash表后，上层Seq Scan节点扫描Client表并在hash表中进行匹配。

   `Seq Scan on public.client c  (cost=0.00..1.11 rows=11 width=16) (actual time=0.010..0.012 rows=11 loops=1)`

   成本计算：

   `seq_page_cost * p.relpages + cpu_tuple_cost * p.reltuples=1*1+0.01*11=1.11`

4. Hash Join节点进行连接。

   ` Hash Join  (cost=1.12..2.29 rows=1 width=12) (actual time=0.039..0.045 rows=1 loops=1)`

   成本计算：

   启动需要构建hash table和自身的一些启动成本，所以启动成本约等于Hash节点的总成本+自身启动成本。

   `1.11+hashjoin_startup_cost=1.12`

   总成本即为启动成本+Client的全表扫描的成本+HashJoin自己的成本。

   `1.12+1.11+hashjoincost=2.29`

### 执行计划——nested loop

```sql
postgres=# set enable_hashjoin=0;
postgres=# explain (analyze,verbose,buffers,timing,costs) select name from client c left join package p on c.accountnumber=recipient where p.weight=1.5;
                                                    QUERY PLAN                                                    
------------------------------------------------------------------------------------------------------------------
 Nested Loop  (cost=0.00..2.36 rows=1 width=12) (actual time=0.030..0.043 rows=1 loops=1)
   Output: c.name
   Join Filter: (c.accountnumber = p.recipient)
   Rows Removed by Join Filter: 10
   Buffers: shared hit=2
   ->  Seq Scan on public.package p  (cost=0.00..1.11 rows=1 width=4) (actual time=0.019..0.024 rows=1 loops=1)
         Output: p.shipment, p.packagenumber, p.contents, p.weight, p.sender, p.recipient
         Filter: (p.weight = '1.5'::double precision)
         Rows Removed by Filter: 8
         Buffers: shared hit=1
   ->  Seq Scan on public.client c  (cost=0.00..1.11 rows=11 width=16) (actual time=0.004..0.008 rows=11 loops=1)
         Output: c.accountnumber, c.name
         Buffers: shared hit=1
 Planning time: 0.431 ms
 Execution time: 0.099 ms
(15 rows)
```

for  tuple in 外(左)表查询 loop

​     内(右)表查询(根据左表查询得到的行作为右表查询的条件依次输出最终结果)

endloop;

1. 先看内层的第一个Seq Scan，选择条件被下推到外表的扫描中了，这样可以直接减少对内表循环扫描的次数。
2. 因为外表过滤完了就一层，所以内表只做了一遍seq scan，seqscan的成本计算同上个分析结果。
3. 最外层成本 = 外表扫描成本 + 内表扫描成本 * 外表rows，这里外表rows=1（过滤之后的package表）。

### 执行计划——merge join

```sql
postgres=# set enable_nestloop=0;
SET
postgres=# explain (analyze,verbose,buffers,timing,costs) select name from client c left join package p on c.accountnumber=recipient where p.weight=1.5;
                                                       QUERY PLAN                                                       
------------------------------------------------------------------------------------------------------------------------
 Merge Join  (cost=2.42..2.48 rows=1 width=12) (actual time=0.075..0.079 rows=1 loops=1)
   Output: c.name
   Merge Cond: (c.accountnumber = p.recipient)
   Buffers: shared hit=2
   ->  Sort  (cost=1.30..1.33 rows=11 width=16) (actual time=0.045..0.046 rows=3 loops=1)
         Output: c.name, c.accountnumber
         Sort Key: c.accountnumber
         Sort Method: quicksort  Memory: 25kB
         Buffers: shared hit=1
         ->  Seq Scan on public.client c  (cost=0.00..1.11 rows=11 width=16) (actual time=0.015..0.021 rows=11 loops=1)
               Output: c.name, c.accountnumber
               Buffers: shared hit=1
   ->  Sort  (cost=1.12..1.13 rows=1 width=4) (actual time=0.021..0.021 rows=1 loops=1)
         Output: p.recipient
         Sort Key: p.recipient
         Sort Method: quicksort  Memory: 25kB
         Buffers: shared hit=1
         ->  Seq Scan on public.package p  (cost=0.00..1.11 rows=1 width=4) (actual time=0.010..0.015 rows=1 loops=1)
               Output: p.recipient
               Filter: (p.weight = '1.5'::double precision)
               Rows Removed by Filter: 8
               Buffers: shared hit=1
 Planning time: 0.434 ms
 Execution time: 0.173 ms
(24 rows)
```

首先两个JOIN的表根据join key进行排序，然后根据joinkey的排序顺序并行扫描两个表进行匹配输出最终结果，适合大表并且索引列进行关联的情况。

1. merge join的两个供数节点必须提供有序的数据，所以现在是 sort也可能是index扫描。
2. 当前sort节点使用seq scan扫描并排序，seqscan的成本计算同上个分析结果。



## 问题3：What is the total weight of all the packages that he sent?

### SQL1

```sql
postgres=# select SUM(p.weight)  from Client as c join Package as P on c.AccountNumber = p.Sender where c.Name = 'Al Gore''s Head';
 sum 
-----
  17
(1 row)

postgres=# select relpages,reltuples from pg_class where relname='client';
 relpages | reltuples 
----------+-----------
        1 |        11
(1 row)

postgres=# select relpages,reltuples from pg_class where relname='package';
 relpages | reltuples 
----------+-----------
        1 |         9
(1 row)
```

### 执行计划——hash join

```sql
postgres=# explain (analyze,verbose,buffers,timing,costs) SELECT SUM(p.weight) 
postgres-# FROM Client AS c 
postgres-#   JOIN Package as P 
postgres-#   ON c.AccountNumber = p.Sender
postgres-# WHERE c.Name = 'Al Gore''s Head';
                                                        QUERY PLAN                                                         
---------------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=2.29..2.30 rows=1 width=4) (actual time=0.083..0.083 rows=1 loops=1)
   Output: sum(p.weight)
   Buffers: shared hit=2
   ->  Hash Join  (cost=1.15..2.28 rows=1 width=4) (actual time=0.067..0.075 rows=2 loops=1)
         Output: p.weight
         Hash Cond: (p.sender = c.accountnumber)
         Buffers: shared hit=2
         ->  Seq Scan on public.package p  (cost=0.00..1.09 rows=9 width=8) (actual time=0.013..0.016 rows=9 loops=1)
               Output: p.shipment, p.packagenumber, p.contents, p.weight, p.sender, p.recipient
               Buffers: shared hit=1
         ->  Hash  (cost=1.14..1.14 rows=1 width=4) (actual time=0.038..0.038 rows=1 loops=1)
               Output: c.accountnumber
               Buckets: 1024  Batches: 1  Memory Usage: 9kB
               Buffers: shared hit=1
               ->  Seq Scan on public.client c  (cost=0.00..1.14 rows=1 width=4) (actual time=0.011..0.016 rows=1 loops=1)
                     Output: c.accountnumber
                     Filter: (c.name = 'Al Gore''s Head'::text)
                     Rows Removed by Filter: 10
                     Buffers: shared hit=1
 Planning time: 0.430 ms
 Execution time: 0.211 ms
(21 rows)
```

1. hash join总是下挂两个节点，一个是构造hash表，一个是扫描。

2. 在Hash节点上，成本是1.14直接继承了下挂的全表扫描的成本，构造hash表的成本太低没有体现。

3. 在最底层的Seq Scan节点上发现成本为1.14，被下推下来的过滤条件过滤后只返回了1行。成本计算：

   11行  * 0.01 + 1块 * 1 + 运算符成本 = 1.11 + 运算符成本 = 1.14

4. 上层Seq Scan扫描package表，成本计算： 1块 * 1 + 9行 * 0.01 = 1.09。

5. Hash Join的启动成本主要在于构造哈希表，所以接近Hash节点成本。而后进行hash连接时需要加上下层seq scan节点的成本，即2.28 ≈ 1.09 + 1.14 = 2.23。

6. 顶层Aggregate节点进行sum聚合，启动成本约为Hash Join的总成本，自身计算成本为0.01。

### 执行计划——nested loop

```sql
postgres=# explain (analyze,verbose,buffers,timing,costs) SELECT SUM(p.weight) 
FROM Client AS c 
  JOIN Package as P 
  ON c.AccountNumber = p.Sender
WHERE c.Name = 'Al Gore''s Head';
                                                      QUERY PLAN                                                      
----------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=2.34..2.35 rows=1 width=4) (actual time=0.052..0.052 rows=1 loops=1)
   Output: sum(p.weight)
   Buffers: shared hit=2
   ->  Nested Loop  (cost=0.00..2.34 rows=1 width=4) (actual time=0.031..0.041 rows=2 loops=1)
         Output: p.weight
         Join Filter: (c.accountnumber = p.sender)
         Rows Removed by Join Filter: 7
         Buffers: shared hit=2
         ->  Seq Scan on public.client c  (cost=0.00..1.14 rows=1 width=4) (actual time=0.020..0.024 rows=1 loops=1)
               Output: c.accountnumber, c.name
               Filter: (c.name = 'Al Gore''s Head'::text)
               Rows Removed by Filter: 10
               Buffers: shared hit=1
         ->  Seq Scan on public.package p  (cost=0.00..1.09 rows=9 width=8) (actual time=0.005..0.009 rows=9 loops=1)
               Output: p.shipment, p.packagenumber, p.contents, p.weight, p.sender, p.recipient
               Buffers: shared hit=1
 Planning time: 0.454 ms
 Execution time: 0.141 ms
(18 rows)
```

Nested Loop的第二个Seq Scan节点由于外表已经过滤只剩下1行，所以该节点只loop了一遍，成本计算即为单次全表扫描的成本，另外可以看到Nested Loop总是挂两个扫描节点，而且第一个是外表扫描，扫出来的每一行都需要使第二个扫描节点循环一次，和循环嵌套连接的定义一致。这里的结果同上面nested loop的结果基本一致。

### SQL2

```sql
postgres=# SELECT SUM(p.weight) 
postgres-# FROM Client AS c 
postgres-#   JOIN Package as P 
postgres-#   ON c.AccountNumber = p.Sender
postgres-# WHERE c.AccountNumber = (
postgres(#   SELECT Client.AccountNumber
postgres(#   FROM Client JOIN Package 
postgres(#     ON Client.AccountNumber = Package.Recipient 
postgres(#   WHERE Package.weight = 1.5
postgres(# );
 sum 
-----
  17
(1 row)
```

### 执行计划

```sql
postgres=# explain (analyze,verbose,buffers,timing,costs) SELECT SUM(p.weight) 
postgres-# FROM Client AS c 
postgres-#   JOIN Package as P 
postgres-#   ON c.AccountNumber = p.Sender
postgres-# WHERE c.AccountNumber = (
postgres(#   SELECT Client.AccountNumber
postgres(#   FROM Client JOIN Package 
postgres(#     ON Client.AccountNumber = Package.Recipient 
postgres(#   WHERE Package.weight = 1.5
postgres(# );
                                                         QUERY PLAN                                                         
----------------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=4.56..4.57 rows=1 width=4) (actual time=0.143..0.143 rows=1 loops=1)
   Output: sum(p.weight)
   Buffers: shared hit=7
   InitPlan 1 (returns $0)
     ->  Hash Join  (cost=1.12..2.29 rows=1 width=4) (actual time=0.086..0.092 rows=1 loops=1)
           Output: client.accountnumber
           Hash Cond: (client.accountnumber = package.recipient)
           Buffers: shared hit=5
           ->  Seq Scan on public.client  (cost=0.00..1.11 rows=11 width=4) (actual time=0.003..0.006 rows=11 loops=1)
                 Output: client.accountnumber, client.name
                 Buffers: shared hit=1
           ->  Hash  (cost=1.11..1.11 rows=1 width=4) (actual time=0.031..0.031 rows=1 loops=1)
                 Output: package.recipient
                 Buckets: 1024  Batches: 1  Memory Usage: 9kB
                 Buffers: shared hit=1
                 ->  Seq Scan on public.package  (cost=0.00..1.11 rows=1 width=4) (actual time=0.020..0.025 rows=1 loops=1)
                       Output: package.recipient
                       Filter: (package.weight = '1.5'::double precision)
                       Rows Removed by Filter: 8
                       Buffers: shared hit=1
   ->  Nested Loop  (cost=0.00..2.27 rows=2 width=4) (actual time=0.120..0.126 rows=2 loops=1)
         Output: p.weight
         Buffers: shared hit=7
         ->  Seq Scan on public.client c  (cost=0.00..1.14 rows=1 width=4) (actual time=0.114..0.116 rows=1 loops=1)
               Output: c.accountnumber, c.name
               Filter: (c.accountnumber = $0)
               Rows Removed by Filter: 10
               Buffers: shared hit=6
         ->  Seq Scan on public.package p  (cost=0.00..1.11 rows=2 width=8) (actual time=0.004..0.006 rows=2 loops=1)
               Output: p.shipment, p.packagenumber, p.contents, p.weight, p.sender, p.recipient
               Filter: (p.sender = $0)
               Rows Removed by Filter: 7
               Buffers: shared hit=1
 Planning time: 1.620 ms
 Execution time: 0.331 ms
(35 rows)
```

1. 第一个Hash Join节点为括号内的子查询，该节点在package表上构造hash表，然后扫描client表进行连接。
2. 上层的Nested Loop  (cost=0.00..2.27 rows=2 width=4)节点下的第一个全表扫描，正在扫描client表，注意这里有筛选条件：`Filter: (c.accountnumber = $0)`，这个条件是由Hash Join节点计算得到的，说明子查询的计划优先执行，使用子查询的结果填充到后面的计划中。注意这个全表扫描还是返回了1行，所以nestedloop的第二个seqscan只循环了一遍。
3. 循环嵌套连接的第二个全表扫描节点也用到了子查询传入的值`Filter: (p.sender = $0)` 。

