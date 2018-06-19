# 构造postgresql测试数据库（填充一个数据库）

## 背景

很多数据库都提供了测试数据集，这里参考pg官方wiki给出的方案，构造几种测试数据集。

**填充数据库需要注意几点，这里一并说明并测试。**

参考原文：https://wiki.postgresql.org/wiki/Sample_Databases

## 填充数据库

- 使用COPY 
- 移除索引 
- 移除外键约束 
- 增加maintenance_work_mem 
- 增加max_wal_size 
- 禁用WAL 归档和流复制 
- 事后运行ANALYZE 
- 使用pg_dump和pg_restore 的并发模式

## 数据集

### World



### dellstore2



### Pagila



### The land registry file



###  其他

- [AdventureWorks 2014 for Postgres](https://github.com/lorint/AdventureWorks-for-Postgres) - Scripts to set up the OLTP part of the go-to database used in training classes and for sample apps on the Microsoft stack. The result is 68 tables containing HR, sales, product, and purchasing data organized across 5 schemas. It represents a fictitious bicycle parts wholesaler with a hierarchy of nearly 300 employees, 500 products, 20000 customers, and 31000 sales each having an average of 4 line items. So it's big enough to be interesting, but not unwieldy. In addition to being a well-rounded OLTP sample, it is also a good choice to demonstrate ETL into a data warehouse. The code in some of the views demonstrates effective techniques for querying XML data.
- [Mouse Genome sample data set](http://www.informatics.jax.org/downloads/database_backups/). See [instructions](http://www.informatics.jax.org/software.shtml). Custom format dump, 1.9GB compressed, but restored database is tens of GB in size. MGI is the international database resource for the laboratory mouse, providing integrated genetic, genomic, and biological data to facilitate the study of human health and disease. MGI use PostgreSQL in production [[1\]](http://www.ncbi.nlm.nih.gov/pmc/articles/PMC3245042/), providing direct protocol access to researchers, so the custom format dump is not an afterthought. Apparently updated frequently.
- Benchmarking databases such as [DBT-2](https://wiki.postgresql.org/wiki/DBT-2) or [TPC-H](https://wiki.postgresql.org/wiki/TPC-H) can be used as samples.
- [Freebase](http://www.freebase.com/docs/data_dumps) - Various wiki style data on places/people/things - ~600MB compressed
- [IMDB](http://www.imdb.com/interfaces#plain) - the IMDB database - see also <http://code.google.com/p/imbi/>
- [[2\]](http://www.data.gov/) - US federal government data collection see also [sunlightlabs](http://www.sunlightlabs.com/)
- [DBpedia](http://wiki.dbpedia.org/Downloads) - wikipedia data export project
- [eoddata](http://www.eoddata.com/) - historic stock market data (requires registration - licence?)
- [RITA](http://www.transtats.bts.gov/Tables.asp?DB_ID=120&DB_Name=Airline%20On-Time%20Performance%20Data&DB_Short_Name=On-Time) - Airline On-Time Performance Data
- [Openstreetmap](http://wiki.openstreetmap.org/wiki/Planet.osm) - Openstreetmap source data
- [NCBI](ftp://ftp.ncbi.nih.gov/gene/DATA/) - biological annotation from NCBI's ENTREZ system (daily updated)
- [Airlines Demo Database (in Russian)](https://postgrespro.ru/education/demodb) - Airlines Demo Database provides database schema with several tables and meaningful content, which can be used for learning SQL and writing applications