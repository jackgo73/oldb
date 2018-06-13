#  postgresql全文搜索

> gaomingjie
>
> Email: jackgo73@outlook.com
>
> Date:  20180611

## 背景

根据手册内容总结实践full text search。手册内容穿插笔记和实践（标记：>>>笔记<<<）。

## 介绍

- 全文搜索提供了确定满足一个查询的自然语言文档的能力，并可以选择将它们按照与查询的相关度排序。
- PostgreSQL对 文 本 数 据 类 型 提 供了~、~*、LIKE和ILIKE操作符吗，缺点：
  - 缺乏语言的支持。正则表达式是不够的，因为它们不能很容易地处理派生词，例如satisfies和satisfy。你可能会错过包含satisfies的文档，尽管你可能想要在对于satisfy的搜索中找到它们。可以使用OR来搜索多个派生形式，但是这样做太罗嗦也容易出错（有些词可能有数千种派生）。 
- 不能提供对搜索结果的排序（排名），这使它们面对数以千计被找到的文档时变得无效。 
- 它们很慢因为没有索引支持，因此它们必须为每次搜索处理所有的文档。 



全文检索上场：

- 全文索引允许文档被预处理并且保存一个索引用于以后快速的搜索。预处理包括： 
  - 将文档解析成记号。标识出多种类型的记号是有所帮助的，例如数字、词、复杂的词、电子邮件地址，这样它们可以被以不同的方式处理。原则上记号分类取决于相关的应用，但是对于大部分目的都可以使用一套预定义的分类。PostgreSQL使用一个解析器来执行这个步骤。其中提供了一个标准的解析器，并且为特定的需要也可以创建定制的解析器。 
  - 将记号转换成词位。和一个记号一样，一个词位是一个字符串，但是它已经被正规化，这样同一个词的不同形式被变成一样。例如，正规化几乎总是包括将大写字母转换成小写形式，并且经常涉及移除后缀（例如英语中的s或es）。这允许搜索找到同一个词的变体形式，而不需要冗长地输入所有可能的变体。此外，这个步骤通常会消除停用词，它们是那些太普通的词，它们对于搜索是无用的（简而言之，记号是文档文本的原始片段，而词位是那些被认为对索引和搜索有用的词）。PostgreSQL使用词典来执行这个步骤。已经提供了多种标准词典，并且为特定的需要也可以创建定制的词典。 
  - 为搜索优化存储预处理好的文档。例如，每一个文档可以被表示为正规化的词位的一个有序数组。与词位一起，通常还想要存储用于近似排名的位置信息，这样一个包含查询词更“密集”区域的文档要比那些包含分散的查询词的文档有更高的排名。
- 词典允许对记号如何被正规化进行细粒度的控制。使用合适的词典，你可以： 
  - 定义不应该被索引的停用词。
  - 使用Ispell把同义词映射到一个单一词。
  - 使用一个分类词典把短语映射到一个单一词。
  - 使用一个Ispell词典把一个词的不同变体映射到一种规范的形式。
  - 使用Snowball词干分析器规则将一个词的不同变体映射到一种规范的形式。 
- 提供了一种数据类型tsvector来存储预处理后的文档，还提供了一种类型tsquery来表示处理过的查询（Section 8.11）。有很多函数和操作符可以用于这些数据类型（Section 9.13），其中最重要的是匹配操作符@@，它在Section 12.1.2中介绍。全文搜索可以使用索引来加速（Section 12.9）。 

---

**>>>我来理解一下<<<**

- 全文搜索是预处理了一下之后产生了一个索引
- 预处理先把文档做分词，然后给每个词都做记号，然后把记号转成词位，词位是标准化的记号。（例如同一个词的不同形式的记号相同）pg有词典来做这个事情。
- tsvector来存储预处理后的文档 
- tsquery来表示处理过的查询 

---

### 什么是一个文档？ 

- 一个document是在一个全文搜索系统中进行搜索的单元，例如，一篇杂志文章或电子邮件消息。文本搜索引擎必须能够解析文档并存储词位（关键词）与它们的父文档之间的关联。随后，这些关联会被用来搜索包含查询词的文档。

- 对于PostgreSQL中的搜索，一个文档通常是一个数据库表中一行内的一个文本形式的域，或者可能是这类域的一个组合（连接），这些域可能存储在多个表或者是动态获取。换句话说，一个文档可能从用于索引的不同部分构建，并且它可能被作为一个整体存储在某个地方。例如：

   ```sql
   SELECT title || ’ ’ || author || ’ ’ || abstract || ’ ’ || body AS document
   FROM messages
   WHERE mid = 12;
   ```
   ```sql
   SELECT m.title || ’ ’ || m.author || ’ ’ || m.abstract || ’ ’ || d.body AS document
   FROM messages m, docs d
   WHERE mid = did AND mid = 12;
   ```

- 另一种存储文档的可能性是作为文件系统中的简单文本文件。在这种情况下，数据库可以被用来存储全文索引并执行搜索，并且某些唯一标识符可以被用来从文件系统检索文档。但是，从数据库的外面检索文件要求超级用户权限或者特殊函数支持，因此这种方法通常不如把所有数据放在PostgreSQL内部方便。另外，把所有东西放在数据库内部允许方便地访问文档元数据来协助索引和现实。

- 对于文本搜索目的，每一个文档必须被缩减成预处理后的tsvector格式。搜索和排名被整个在一个文档的tsvector表示上执行 — 只有当文档被选择来显示给用户时才需要检索原始文本。我们因此经常把tsvector说成是文档，但是当然它只是完整文档的一种紧凑表示。****

---

**>>>我来理解一下<<<**

- 全文搜索的原始文本最好存在数据库里面
- 文档都会被预处理成tsvector的格式，内部处理都是用的这个数据结构，之后最终显示的时候再检索原始文本。

---

### 基本文本匹配 

PostgreSQL中 的 全 文 搜 索 基 于 匹 配 操 作 符@@， 它 在 一 个tsvector（ 文 档 ） 匹 配 一个tsquery（查询）时返回true。哪种数据类型写在前面没有影响：

```sql
SELECT 'a fat cat sat on a mat and ate a fat rat'::tsvector @@ 'cat & rat'::tsquery;
?column?
----------
t
SELECT 'fat & cow'::tsquery @@ 'a fat cat sat on a mat and ate a fat rat'::tsvector;
?column?
----------
f
```



正如以上例子所建议的，一个tsquery并不只是一个未经处理的文本，顶多一个tsvector是这样。一个tsquery包含搜索术语，它们必须是已经正规化的词位，并且可以使用 AND、OR、NOT 以及 FOLLOWED BY 操作符结合多个术语（详见Section 8.11.2）。有几 个 函 数to_tsquery、plainto_tsquery以 及phraseto_tsquery可 用 于 将 用 户 书 写 的文本转换为正确的tsquery，它们会主要采用正则化出现在文本中的词的方法。相似地，to_tsvector被用来解析和正规化一个文档字符串。因此在实际上一个文本搜索匹配可能看起来更像： 

```sql
SELECT to_tsvector('fat cats ate fat rats') @@ to_tsquery('fat & rat');
?column?
----------
t
```

注意如果这个匹配被写成下面这样它将不会成功： 

```sql
SELECT 'fat cats ate fat rats'::tsvector @@ to_tsquery('fat & rat');
?column?
----------
f
```

因为这里不会发生词rats的正规化。一个tsvector的元素是词位，它被假定为已经正规化好，因此rats不匹配rat 

---

**>>>我来理解一下<<<**

- ::tsvector直接转换成文本向量，这个强制转换的东西假定已经正规化了，存的是词位。
- to_tsvector函数将文本正规化处理成词位。

---

@@操 作 符 也 支 持text输 出 ， 它 允 许 在 简 单 情 况 下 跳 过 从 文 本 字 符 串到tsvector或tsquery的显式转换。可用的变体是： 

```sql
tsvector @@ tsquery
tsquery @@ tsvector
text @@ tsquery
text @@ text
```

前两种我们已经见过。形式text @@ tsquery等价于to_tsvector(x) @@ y。形式text @@ text等价于to_tsvector(x) @@ plainto_tsquery(y)。 

在tsquery中，&（AND）操作符指定它的两个参数都必须出现在文档中才表示匹配。类似地，|（OR）操作符指定至少一个参数必须出现，而!（NOT）操作符指定它的参数不出现才能匹配。

在<->（FOLLOWED BY） tsquery操作符的帮助下搜索可能的短语，只有该操作符的参数的匹配是**相邻**的并且符合给定**顺序**时，该操作符才算是匹配。例如： 

```sql
SELECT to_tsvector('fatal error') @@ to_tsquery('fatal <-> error');
?column?
----------
t

SELECT to_tsvector('fatal error') @@ to_tsquery('error <-> fatal');
 ?column? 
----------
 f
(1 row)

SELECT to_tsvector('error is not fatal') @@ to_tsquery('fatal <-> error');
?column?
----------
f
```

FOLLOWED BY 操作符还有一种更一般的版本，形式是\<N>，其中N是一个表示匹配词位位置之间的差\<1>和<->相同，而\<2>允许刚好一个其他词位出现在匹配之间，以此类推。当有些词是停用词时，phraseto_tsquery函数利用这个操作符来构造一个能够匹配多词短语的tsquery。例如： 

```sql
SELECT phraseto_tsquery('cats ate rats');
     phraseto_tsquery      
---------------------------
 'cat' <-> 'ate' <-> 'rat'
(1 row)

SELECT phraseto_tsquery('the cats ate the rats');
     phraseto_tsquery      
---------------------------
 'cat' <-> 'ate' <2> 'rat'
(1 row)
```

一种有时候有用的特殊情况是，\<0>可以被用来要求两个匹配同一个词的模式。圆括号可以被用来控制tsquery操作符的嵌套。如果没有圆括号，|的计算优先级最低，然后从低到高依次是&、<->、!。 

---

**>>>我来理解一下<<<**

- 形式需要记住：转换函数（原始文本） @@ 查询函数（查询条件）

- 注意：转换函数（原始文本）== 词位

- 查询条件里面这里给出了三种： &  |  <-> 其中第三种需要相邻且符合给定顺序。

- <->就是FOLLOW BY操作符。变种可以是 \<N>，见下面例子

  ```sql
  SELECT to_tsvector('error is not fatal') @@ to_tsquery('error <-> fatal');
   ?column? 
  ----------
   f
  (1 row)

  SELECT to_tsvector('error is not fatal') @@ to_tsquery('error <3> fatal');
   ?column? 
  ----------
   t
  (1 row)
  ```

---

### 配置 

- 前述的都是简单的文本搜索例子。正如前面所提到的，全文搜索功能包括做更多事情的能力：跳过索引特定词（停用词）、处理同义词并使用更高级的解析，例如基于空白之外的解析。这个功能由文本搜索配置控制PostgreSQL中有多种语言的预定义配置，并且你可以很容易地创建你自己的配置（psql的\dF命令显示所有可用的配置）。 
- 在 安 装 期 间 一 个 合 适 的 配 置 将 被 选 择 并 且default_text_search_config也 被 相 应 地 设 置在postgresql.conf中。如果你正在对整个集簇使用相同的文本搜索配置，你可以使用在postgresql.conf中使用该值。要在集簇中使用不同的配置但是在任何一个数据库内部使用同一种配置，使用ALTER DATABASE ... SET。否则，你可以在每个会话中设置default_text_search_config。 
- 依赖一个配置的每一个文本搜索函数都有一个可选的regconfig参数，因此要使用的配置可以被显式指定。只有当这个参数被忽略时，default_text_search_config才被使用。为了让建立自定义文本搜索配置更容易，一个配置可以从更简单的数据库对象来建立。PostgreSQL的文本搜索功能提供了四类配置相关的数据库对象： 
  - 文本搜索解析器将文档拆分成记号并分类每个记号（例如，作为词或者数字）
  - 文本搜索词典将记号转变成正规化的形式并拒绝停用词。
  - 文本搜索模板提供位于词典底层的函数（一个词典简单地指定一个模板和一组用于模板的参数）
  - 文本搜索配置选择一个解析器和一组用于将解析器产生的记号正规化的词典。 


- 文本搜索解析器和模板是从低层 C 函数构建而来，因此它要求 C 编程能力来开发新的解析器和模板，并且还需要超级用户权限来把它们安装到一个数据库中（在PostgreSQL发布的contrib/区域中有一些附加的解析器和模板的例子）。由于词典和配置只是对底层解析器和模板的参数化和连接，不需要特殊的权限来创建一个新词典或配置。创建定制词典和配置的例子将在本章稍后的部分给 

---

**>>>我来理解一下<<<**

- 全文搜索还有其他的能力：跳过索引特定词（停用词）、处理同义词并使用更高级的解析，例如基于空白之外的解析等等

- 安装的默认参数是英语语法，使用ALTER DATABASE ... SET修改。

  ```sql
  postgres=# show default_text_search_config;
   default_text_search_config 
  ----------------------------
   pg_catalog.english
  (1 row)
  ```

---

## 表和索引 

在前一节中的例子演示了使用简单常数字符串进行全文匹配。本节展示如何搜索表数据，以及可选择地使用索引。 

### 搜索一个表 

---

**>>>按照文档构造数据操作一遍<<<**

```sql
create table pgweb (id int primary key, title text, body text, last_mod_date date);

insert into pgweb values (1, 'Tag', 'A small group of former classmates organize an elaborate, annual game of tag that requires some to travel all over the country.', '2018-06-01');
insert into pgweb values (2, 'Gotti', 'The story of crime boss John Gotti and his son.', '2018-06-02');
insert into pgweb values (3, 'Race 3', 'Revolves around a family that deals in borderline crime; ruthless and vindictive to the core.', '2018-06-04');
insert into pgweb values (4, 'SuperFly', $$The movie is a remake of the 1972 blaxploitation film 'Super Fly'.$$, '2018-06-04');
insert into pgweb values (5, 'Incredibles 2', 'Bob Parr (Mr. Incredible) is left to care for Jack-Jack while Helen (Elastigirl) is out saving the world.', '2018-06-05');

insert into pgweb values (6, 'Friends1', 'xxx aaa friend friends friendly.', '2018-06-07');
insert into pgweb values (7, 'Friends2', 'xxx aaa friends.', '2018-06-07');
insert into pgweb values (8, 'Friends3', 'xxx aaa friendly.', '2018-06-08');
```

可以在没有一个索引的情况下做一次全文搜索。一个简单的查询将打印每一个行的title，这些行在其body域中包含词friend： 

```sql
postgres=# SELECT title FROM pgweb WHERE to_tsvector('english', body) @@ to_tsquery('english', 'friend');
  title   
----------
 Friends1
 Friends2
 Friends3
(3 rows)
```

这将还会找到相关的词例如friends和friendly，因为这些都被约减到同一个正规化的词位。以上的查询指定要使用english配置来解析和正规化字符串。我们也可以忽略配置参数，这个查询将使用由default_text_search_config设置的配置。 

```sql
postgres=# SELECT title FROM pgweb WHERE to_tsvector(body) @@ to_tsquery('friend');
  title   
----------
 Friends1
 Friends2
 Friends3
(3 rows)
```

一 个 更 复 杂 的 例 子 要 求 它 们 在title或body中 包含create和table 

```sql
postgres=# SELECT title FROM pgweb WHERE to_tsvector(title || ' ' || body) @@ to_tsquery('tag & country');
 title 
-------
 Tag
(1 row)
```

为了清晰，我们忽略coalesce函数调用，它可能需要被用来查找在这两个域之中包含NULL的行。
尽管这些查询可以在没有索引的情况下工作，大部分应用会发现这种方法太慢了，除了偶尔的临时搜索。实际使用文本搜索通常要求创建一个索引。 

---

### 创建索引 

------

**>>>按照文档构造数据操作<<<**

我们可以创建一个GIN索引（Section 12.9）来加速文本搜索：

```sql
postgres=# CREATE INDEX pgweb_idx ON pgweb USING GIN(to_tsvector('english', body)); 
CREATE INDEX
```

**注意**必须使用双参数版本的to_tsvector才能走索引，即WHERE to_tsvector(’english’,body) @@ ’a & b’ 可以使用该索引，但WHERE to_tsvector(body) @@ ’a & b’不能 。



另 一 种 方 法 是 创 建 一 个 单 独 的tsvector列 来 保 存to_tsvector的 输 出 。 这 个 例 子是title和body的连接，使用coalesce来保证当其他域为NULL时一个域仍然能留在索引中：

```sql
ALTER TABLE pgweb ADD COLUMN textsearchable_index_col tsvector;
UPDATE pgweb SET textsearchable_index_col = to_tsvector('english', coalesce(title,'') || ' ' || coalesce(body,''));
```

 ps.看看to_tsvector后是什么样子

```sql
postgres=# select body, to_tsvector('english', body) from pgweb;
-[ RECORD 1 ]-------------------------------------------------------------------------------------------------------------------------------------
body        | The story of crime boss John Gotti and his son.
to_tsvector | 'boss':5 'crime':4 'gotti':7 'john':6 'son':10 'stori':2
-[ RECORD 2 ]-------------------------------------------------------------------------------------------------------------------------------------
body        | Revolves around a family that deals in borderline crime; ruthless and vindictive to the core.
to_tsvector | 'around':2 'borderlin':8 'core':15 'crime':9 'deal':6 'famili':4 'revolv':1 'ruthless':10 'vindict':12
-[ RECORD 3 ]-------------------------------------------------------------------------------------------------------------------------------------
body        | The movie is a remake of the 1972 blaxploitation film 'Super Fly'.
to_tsvector | '1972':8 'blaxploit':9 'film':10 'fli':12 'movi':2 'remak':5 'super':11
-[ RECORD 4 ]-------------------------------------------------------------------------------------------------------------------------------------
body        | Bob Parr (Mr. Incredible) is left to care for Jack-Jack while Helen (Elastigirl) is out saving the world.
to_tsvector | 'bob':1 'care':8 'elastigirl':15 'helen':14 'incred':4 'jack':11,12 'jack-jack':10 'left':6 'mr':3 'parr':2 'save':18 'world':20
-[ RECORD 5 ]-------------------------------------------------------------------------------------------------------------------------------------
body        | A small group of former classmates organize an elaborate, annual game of tag that requires some to travel all over the country.
to_tsvector | 'annual':10 'classmat':6 'countri':22 'elabor':9 'former':5 'game':11 'group':3 'organ':7 'requir':15 'small':2 'tag':13 'travel':18
-[ RECORD 6 ]-------------------------------------------------------------------------------------------------------------------------------------
body        | xxx aaa friend friends friendly.
to_tsvector | 'aaa':2 'friend':3,4,5 'xxx':1
-[ RECORD 7 ]-------------------------------------------------------------------------------------------------------------------------------------
body        | xxx aaa friends.
to_tsvector | 'aaa':2 'friend':3 'xxx':1
-[ RECORD 8 ]-------------------------------------------------------------------------------------------------------------------------------------
body        | xxx aaa friendly.
to_tsvector | 'aaa':2 'friend':3 'xxx':1
```

然后我们创建一个GIN索引来加速搜索： 

```sql
CREATE INDEX textsearch_idx ON pgweb USING GIN(textsearchable_index_col);
```

现在我们准备好执行一个快速的全文搜索了，数据量太小了，强制走一下索引。

```sql
SELECT title
FROM pgweb
WHERE textsearchable_index_col @@ to_tsquery('classmat & travel')
ORDER BY last_mod_date DESC
LIMIT 10;

explain (analyze,VERBOSE,COSTS) SELECT title
FROM pgweb
WHERE textsearchable_index_col @@ to_tsquery('classmat & travel')
ORDER BY last_mod_date DESC
LIMIT 10;
                                                             QUERY PLAN                                                             
------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=16.52..16.53 rows=1 width=36) (actual time=0.097..0.098 rows=1 loops=1)
   Output: title, last_mod_date
   ->  Sort  (cost=16.52..16.53 rows=1 width=36) (actual time=0.095..0.096 rows=1 loops=1)
         Output: title, last_mod_date
         Sort Key: pgweb.last_mod_date DESC
         Sort Method: quicksort  Memory: 25kB
         ->  Bitmap Heap Scan on public.pgweb  (cost=12.25..16.51 rows=1 width=36) (actual time=0.082..0.083 rows=1 loops=1)
               Output: title, last_mod_date
               Recheck Cond: (pgweb.textsearchable_index_col @@ to_tsquery('classmat & travel'::text))
               Heap Blocks: exact=1
               ->  Bitmap Index Scan on textsearch_idx  (cost=0.00..12.25 rows=1 width=0) (actual time=0.069..0.069 rows=1 loops=1)
                     Index Cond: (pgweb.textsearchable_index_col @@ to_tsquery('classmat & travel'::text))
 Planning time: 0.288 ms
 Execution time: 0.236 ms
(14 rows)
```

在使用一个单独的列来存储tsvector表示时，有必要创建一个触发器在title或body改变时保证tsvector列为当前值。Section 12.4.3解释了怎样去做。单独列方法相对于表达式索引的一个优势在于，它不必为了利用索引而在查询中显式地指定文本搜索配置。如上述例子所示，查询可以依赖default_text_search_config。另一个优势是搜索将会更快，因为它不必重做to_tsvector调用来验证索引匹配（在使用 GiST 索引时这一点比使用 GIN 索引时更重要；见Section 12.9）。表达式索引方法更容易建立，但是它要求更少的磁盘空间，因为tsvector表示没有被显式地存储下来。 

## 空值文本搜索

