# Postgresql基础LexYacc01

>高铭杰  20180622  jackgo73@outlook.com

《Lex与Yacc》第二版 总结 + 实践。

# 环境

```
yum install flex flex-devel bison bison-devel

# lex使用方法
flex ch1-01.l
gcc lex.yy.c -lfl

# yacc使用方法
flex ch1-05.l
bison -d ch1-05.y
gcc -c lex.yy.c ch1-05.tab.c
gcc -o ch1-05 lex.yy.o ch1-05.tab.o -lfl
```

## 识别单词

```c
%{
/*
 * this sample demonstrates (very) simple recognition:
 * a verb/not a verb.
 */

%}
%%

[\t ]+		/* ignore white space */ ;

is |
am |
are |
were |
was |
be |
being |
been |
do |
does |
did |
will |
would |
should |
can |
could |
has |
have |
had |
go		{ printf("%s: is a verb\n", yytext); }

[a-zA-Z]+ 	{ printf("%s: is not a verb\n", yytext); }

.|\n		{ ECHO; /* normal default anyway */ }
%%

main()
{
	yylex();
}
```

