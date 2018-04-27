# Planet Express案例执行计划&成本分析

https://en.wikibooks.org/wiki/SQL_Exercises/Planet_Express

![](images/sql-exec-hospital-0.png)

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

## Who received a 1.5kg package?

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

### 分析——hash join

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

### 分析——nested loop

for  tuple in 外(左)表查询 loop

​     内(右)表查询(根据左表查询得到的行作为右表查询的条件依次输出最终结果)

endloop;

1. 先看内层的第一个Seq Scan，选择条件被下推到外表的扫描中了，这样可以直接减少内表扫描的次数。
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

### 分析——merge join

首先两个JOIN的表根据join key进行排序，然后根据joinkey的排序顺序并行扫描两个表进行匹配输出最终结果，适合大表并且索引列进行关联的情况。

1. merge join的两个供数节点必须提供有序的数据，所以现在是 sort也可能是index扫面。
2. 当前sort节点使用seq scan扫描并排序，seqscan的成本计算同上个分析结果。



## What is the total weight of all the packages that he sent?

