## Google Style Guides-Shell Style Guide(翻译)

转自：https://yq.aliyun.com/articles/55699

## 背景

### 使用什么shell?

Bash是允许的可执行文件中的的唯一一个shell脚本语言。其可执行文件必须是以`#!/bin/bash开头`，使用set来设置shell的选项，以便你可以按照bash 来调用你的脚本，而不破坏它的功能．限制所有可执行的shell脚本为bash，为我们提供了所安装的所有机器上的一致shell语言。唯一的例外是在种强制要求你编码为某种格式的地方，例如在Solaris SVR4的软件包中所有的脚本都要求是普通的Bourne shell．

### 什么时候使用shell?

shell应该仅仅被使用在一些小的使用工具或包装脚本中．虽然shell脚本不是一种开发语言，但是却用于整个Google公司中用于编写各种实用脚本，这种风格引导更多的是认识它怎么去使用，而不是一个建议，它可用于广泛部署中． 
一些准则: 
\* 如果你主要是调用一些其它的实用程序，和正在做一些相对较少的数据处理，那么shell是该任务可以接受的选择 
\* 如果你在乎性能，那么使用其它开发语言而不是shell 
\* 如果你发现你需要使用数组的地方超过变量赋值，你应该使用python 
\* 如果你写了一个脚本超过100行，你应该考虑使用python来代替，请记住脚本代码量会增长，尽早使用其它语言来重写你的脚本可以避免后期修改带来的大量的时间消耗

## shell文件和解释器调用

### 文件扩展名

可执行文件应该没有扩展名(强烈推荐)，或者使用.sh来作为扩展名，但是库文件必须有.sh作为扩展名，并且不可被执行．当你要执行一个执行文件的时候是没有必要知道这个可执行文件是什么语言编写的，因此shell是不需要扩展名，因此我们不希望给shell可执行文件添加扩展名．然而对于库文件来说，知道库是使用何种语言来编写的这是非常重要的，有的时候不同的语言可能会有相同的库，这就要求库文件必须能被区分，因此不同的语言通过给库文件添加预期的与语言相关的后缀名来进行识别．

### SUID/SGID

SUID/SGID位在shell脚本中应该被禁止使用． 
它们和shell在一起会有太多的安全问题，使其几乎不能确保足以允许SUID/SGID，虽然bash确实让人很难以SUID来运行，但它仍然有可能在一些平台上运行，这就是为什么我们要明确禁止使用它．如果你需要使用较高的权限来执行，使用sudo来代替．

## 环境

### 标准输出 vs 标准错误输出

所有的错误信息应该输入到标准错误输出中 
这使的更容易从实际问题中分离出正常的状态． 
下面这个函数是用于打印出错误信息以及其他状态信息的功能，值得推荐。

```
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

if ! do_something; then
  err "Unable to do_something"
  exit "${E_DID_NOTHING}"
fi
```

## 注释

### 文件头注释

在每一个文件开头处添加一段描述内容 
每一个文件必须有一个顶层注释，这个注释内容包含了一个简短的概述，一个copyright声明，还有一些可选的作者信息 
例子:

```
#!/bin/bash
#
# Perform hot backups of Oracle databases.
```

### 函数注释

任何不能同时具备短小和功能显而易见的函数都必须又一段注释，任何库中的函数，无论其长度大小和复杂性都必须要又注释． 
所有的函数注释应该包含如下的内容: 
\* 函数的描述信息 
\* 使用的和修改的全局变量 
\* 参数信息 
\* 返回值而不是最后一条命令的退出状态码 
例子:

```
#!/bin/bash
#
# Perform hot backups of Oracle databases.

export PATH='/usr/xpg4/bin:/usr/bin:/opt/csw/bin:/opt/goog/bin'

#######################################
# Cleanup files from the backup dir
# Globals:
#   BACKUP_DIR
#   ORACLE_SID
# Arguments:
#   None
# Returns:
#   None
#######################################
cleanup() {
  ...
}
```

### 具体实现细节相关注释

对你的代码中比较棘手的，不容易理解的，不明显的，有趣的，或者是一些重要的部分添加注释 
遵循google的通用编码注释的做法，不注释一切，如果有一个复杂的算法，或者是你在做的一个与众不同的功能，在这些地方放置一个简单的注释即可．

### TODO注释

使用TODO来临时注释一段代码，表明这段代码是一个短期的解决方案，这段代码是够用的，但不完美． 
这个注释分割约定和Google C++ Guide一样． 
所有的TODO类别的注释，应该包含一个全部大写的字符串TODO，后面用括号包含您的用户名，冒号是可选的，这里最好把bug号，或者是ticket号放在TODO注释后面 
例子:

```
# TODO(mrmonkey): Handle the unlikely edge cases (bug ####)
```

## 格式化

虽然你应该修改已有的文件来遵循下面风格，但是任何新编写的代码下面的风格是所必须的．

### 缩进

按照２个空格来缩进，不使用tab来缩进． 
在两个语句块中使用空白行，来提高可读性，缩进是两个空格，无论你做什么，不要使用制表符，对于现有的文件，保留现有使用的缩进．

### 行的长度和字符串长度

一行的长度最大是80个字符． 
如果你必须要写一个长于80个字符的字符串，那么你应该使用EOF或者嵌入一个新行，如果有一个文字字符串长度超过了80个字符，并且不能合理的分割文字字符串，但是强烈推荐你找到一种办法让它更短一点． 
例子:

```
# DO use 'here document's
cat <<END;
I am an exceptionally long
string.
END

# Embedded newlines are ok too
long_string="I am an exceptionally
  long string."
```

### 多个管道

如果管道不能适应一行一个那么应该分割成每行一个．　 
如果管道都适合在一行，那么就使用一行即可． 
如果不是，那么应该分割在每行一个管道，新的一行应该缩进２个空格，这条规则适用于那些通过使用”|”或者是一个逻辑运算符”||”和”&&”等组合起来的链式命令． 
例子:

```
# All fits on one line
command1 | command2

# Long commands
command1 \
  | command2 \
  | command3 \
  | command4
```

### 循环

让`; do`和`; then`和while for 以及if在同一行 
shell中的循环有一点不同，但是我们遵循同样的原则，声明函数时使用括号，`; then`和`; do`应该和if/for/while在同一行，else应该单独在一行，最后的结束语句应该单独在一行，并和开始声明符保持垂直对齐． 
例子:

```
for dir in ${dirs_to_cleanup}; do
  if [[ -d "${dir}/${ORACLE_SID}" ]]; then
    log_date "Cleaning up old files in ${dir}/${ORACLE_SID}"
    rm "${dir}/${ORACLE_SID}/"*
    if [[ "$?" -ne 0 ]]; then
      error_message
    fi
  else
    mkdir -p "${dir}/${ORACLE_SID}"
    if [[ "$?" -ne 0 ]]; then
      error_message
    fi
  fi
done
```

## Case语句

- 通过2个空格来缩进
- 对于一些简单的命令可以放在一行的，需要在右括号后面和;;号前面添加一个空格
- 对于长的，有多个命令的，应该分割成多行，其中匹配项，对于匹配项的处理以及;;号各自在单独的行 
  case和esac中匹配项的表达式应该都在同一个缩进级别，匹配项的处理也应该在另一个缩进级别．通常来说，没有必要给匹配项的表达式添加引号．匹配项的表达式不应该在前面加一个左括号， 避免使用`;&`和`;;&&`等符号． 
  例子:

```
case "${expression}" in
  a)
    variable="..."
    some_command "${variable}" "${other_expr}" ...
    ;;
  absolute)
    actions="relative"
    another_command "${actions}" "${other_expr}" ...
    ;;
  *)
    error "Unexpected expression '${expression}'"
    ;;
esac
```

对于一些简单的匹配项处理操作，可以和匹配项表达式以及`;;`号在同一行，只要表达式仍然可读．这通常适合单字符的选项处理，当匹配项处理操作不能满足单行的情况下，可以将匹配项表达式单独放在一行，匹配项处理操作和`;;`放在同一行，当匹配项操作和匹配项表达式以及`;;`放在同一行的时候在匹配项表达式右括号后面以及`;;`前面放置一个空格． 
例子:

```
verbose='false'
aflag=''
bflag=''
files=''
while getopts 'abf:v' flag; do
  case "${flag}" in
    a) aflag='true' ;;
    b) bflag='true' ;;
    f) files="${OPTARG}" ;;
    v) verbose='true' ;;
    *) error "Unexpected option ${flag}" ;;
  esac
don
```

### 变量表达式

按照优先顺序:保留你所发现的一致性的地方;将你的变量引起来，优先使用”var"而不是"var”，详情请看下文: 
下面给出的约定目的只是指导性的，如果把这些约定作为强制性规定似乎太有争议了． 
这些约定按照下面的优先顺序列出: 
\1. 保留你发现的现有代码的一致性的地方 
\2. 将你的变量引起来，请看”引用”这个章节 
\3. 不要对单个字符的shell特殊变量或者是位置参数使用括号引用，除非强烈需求或者是为了避免深层次的困惑，优先使用括号引用其它任何变量

例子:

```
# Section of recommended cases.

# Preferred style for 'special' variables:
# 不要对单个字符的shell特殊变量或者是位置参数使用括号引用
echo "Positional: $1" "$5" "$3"
echo "Specials: !=$!, -=$-, _=$_. ?=$?, #=$# *=$* @=$@ \$=$$ ..."

# Braces necessary:
# 避免深层次的困扰，$1和$10
echo "many parameters: ${10}"

# Braces avoiding confusion:
# Output is "a0b0c0"
set -- a b c
# 避免困惑
echo "${1}0${2}0${3}0"
#　其它变量优先使用括号引用
# Preferred style for other variables:
echo "PATH=${PATH}, PWD=${PWD}, mine=${some_var}"
while read f; do
  echo "file=${f}"
done < <(ls -l /tmp)

# Section of discouraged cases

# Unquoted vars, unbraced vars, brace-quoted single letter
# shell specials.
echo a=$avar "b=$bvar" "PID=${$}" "${1}"

# Confusing use: this is expanded as "${1}0${2}0${3}0",
# not "${10}${20}${30}
set -- a b c
echo "$10$20$30"
```

### 引用

- 总是对包含变量的字符串，命令替换，空格或者是shell元字符进行引用，除非未引用的表达式是必须的．
- 更倾向于引用包含单词的字符串，而不是命令选项和路径名称．
- 不对字面整数进行引用
- 小心对于`[[`括号中的模式匹配使用引用规则(具体细节见特性和bug章节的`Test, [ and [[`部分)
- 使用”@"除非你有特殊理由去使用*

例子:

```
# 单引号引用，表明不需要变量或者命令替换
# 'Single' quotes indicate that no substitution is desired.
# 双引号引用，表明是需要变量或者命令替换的
# "Double" quotes indicate that substitution is required/tolerated.

# Simple examples
# "quote command substitutions"
# 双引号引用，引用内部进行变量替换
flag="$(some_command and its args "$@" 'quoted separately')"

# "quote variables"
echo "${flag}"

# "never quote literal integers"
# 不对字面整数引用
value=32
# "quote command substitutions", even when you expect integers
number="$(generate_number)"

# "prefer quoting words", not compulsory
# 优先引用是单词的字符串，这不是必须的．
readonly USE_INTEGER='true'

# 引用shell元字符
# "quote shell meta characters"
echo 'Hello stranger, and well met. Earn lots of $$$'
echo "Process $$: Done making \$\$\$."
# 命令选项和路径名不要引用
# "command options or path names"
# ($1 is assumed to contain a value here)
grep -li Hugo /dev/null "$1"

# Less simple examples
# "quote variables, unless proven false": ccs might be empty
git send-email --to "${reviewers}" ${ccs:+"--cc" "${ccs}"}

# Positional parameter precautions: $1 might be unset
# Single quotes leave regex as-is.
grep -cP '([Ss]pecial|\|?characters*)$' ${1:+"$1"}

# For passing on arguments,
# 对于参数传递来说，"$@"几乎总是正确的，而$*总是错误的
# "$@" is right almost everytime, and
# $* is wrong almost everytime:
# 
# * $* and $@ will split on spaces, clobbering up arguments
#   that contain spaces and dropping empty strings;
# $@保持参数的原样，因此没有参数提供的时候，就不会有参数传递．
# * "$@" will retain arguments as-is, so no args
#   provided will result in no args being passed on;
#   This is in most cases what you want to use for passing
#   on arguments.
# $*将参数扩展成一个参数，所有的参数通常是按照空格连接，当没有提供参数的时候，将会导致一个空的字符串被传递．
# * "$*" expands to one argument, with all args joined
#   by (usually) spaces,
#   so no args provided will result in one empty string
#   being passed on.
# (Consult 'man bash' for the nit-grits ;-)

set -- 1 "2 two" "3 three tres"; echo $# ; set -- "$*"; echo "$#, $@")
set -- 1 "2 two" "3 three tres"; echo $# ; set -- "$@"; echo "$#, $@")
```

## 特性和bug

### 命令替换

使用(command)替换反引号引用进行命令替换．引号嵌套的时候，需要在内部的引号使用\进行转义，但是(command)的这种格式在嵌套的时候格式不需要改变，易读． 
例子:

```
# This is preferred:
var="$(command "$(command1)")"

# This is not:
var="`command \`command1\``"
```

### Test, [ and [[

`[[... ]]`条件测试要优于`[...]`条件测试 
`[[... ]]`　减少了错误，没有路径名扩展，允许使用正则表达式和通配符，而`[...]`不行． 
例子:

```
# This ensures the string on the left is made up of characters in the
# alnum character class followed by the string name.
# Note that the RHS should not be quoted here.
# For the gory details, see
# E14 at http://tiswww.case.edu/php/chet/bash/FAQ
# 正则表达式匹配，模式不能被引用
if [[ "filename" =~ ^[[:alnum:]]+name ]]; then
  echo "Match"
fi

#　这里filename是要和精确字符串f*匹配，而不是和f*匹配模式进行匹配，模式是不能被引用的
# This matches the exact pattern "f*" (Does not match in this case)
if [[ "filename" == "f*" ]]; then
  echo "Match"
fi

# 因为路径名扩展导致f*扩展为当前目录下以f开头的文件和目录名，导致出现"too many argument"错误
# This gives a "too many arguments" error as f* is expanded to the
# contents of the current directory
if [ "filename" == f* ]; then
  echo "Match"
fi
```

### 字符串测试

使用引号而不是填充可能的字符 
bash在处理测试一个空字符串是足够聪明的，因此鉴于让代码更易读，使用测试标志来测试字符串是否为空，而不是填充字符(见代码示例) 
例子:

```
# Do this:
if [[ "${my_var}" = "some_string" ]]; then
  do_something
fi

# -z (string length is zero) and -n (string length is not zero) are
# preferred over testing for an empty string
if [[ -z "${my_var}" ]]; then
  do_something
fi

# This is OK (ensure quotes on the empty side), but not preferred:
if [[ "${my_var}" = "" ]]; then
  do_something
fi

# Not this:
if [[ "${my_var}X" = "some_stringX" ]]; then
  do_something
fi
```

为了避免困惑，你应该显示的使用-z或-n来测试字符串 
例子:

```
# Use this
if [[ -n "${my_var}" ]]; then
  do_something
fi

# Instead of this as errors can occur if ${my_var} expands to a test
# flag
# 如果my_var替换为一个测试标志将会发生错误．
if [[ "${my_var}" ]]; then
  do_something
fi
```

### 文件名的通配符扩展

当做文件名通配符扩展的时候，使用显式路径． 
作为文件名可以使用`-`开头，这对于使用`*`代替`./*`有很大的安全隐患． 
例子:

```
# Here's the contents of the directory:
# 当前目录下又-f -r somedir somefile等文件和目录
# -f  -r  somedir  somefile

# 使用rm -v *将会扩展成rm -v -r -f somedir simefile，这将导致删除当前目录所有的文件和目录
# This deletes almost everything in the directory by force
psa@bilby$ rm -v *
removed directory: `somedir'
removed `somefile'

#相反如果你使用./*则不会，因为-r -f就不会变成rm的参数了
# As opposed to:
psa@bilby$ rm -v ./*
removed `./-f'
removed `./-r'
rm: cannot remove `./somedir': Is a directory
removed `./somefile'
```

### Eval

eval命令应该被禁止执行． 
eval用于给变量赋值的时候，可以设置变量，但是不能检查这些变量是什么 
例子:

```
# What does this set?
# Did it succeed? In part or whole?
eval $(set_my_variables)

# What happens if one of the returned values has a space in it?
variable="$(eval some_function)"
```

### Pipes to While

使用进程替换，或for循环，要优于pipes to while(见下文)，变量在while循环中修改的时候不会传播到上层作用域．因为循环命令是在子shell中运行的．pipe to while是在子shell中运行的，出现bug的时候很难追踪． 
例子:

```
#在while内部修改last_line将不会影响上层作用域中的last_line变量的
last_line='NULL'
your_command | while read line; do
  last_line="${line}"
done

# This will output 'NULL'
echo "${last_line}"
```

如果你确信输入不会包含空格和特殊字符的话，你可以使用for循环 
例子:

```
total=0
# Only do this if there are no spaces in return values.
for value in $(command); do
  total+="${value}"
done
```

使用进程替换允许重定向输入，并且命令是在一个显示的子shell中运行的，而不是像bash给while loop创建的隐式子shell． 
例子:

```
total=0
last_file=
while read count filename; do
  total+="${count}"
  last_file="${filename}"
done <<(your_command | uniq -c) #这里使用()显示子shell运行进程替换，并且允许重定向输入．
# This will output the second field of the last line of output from
# the command.
echo "Total = ${total}"
echo "Last one = ${last_file}"
```

使用while循环的时候，如果不需要传递一些复杂的结果给上层作用域，这通常需要一些复杂的解析，往往使用一些简单的命令配合awk这样的工具做起来更加简单，当你不想去改变上层作用域的全局变量的时候这种方法很有用． 
例子:

```
# Trivial implementation of awk expression:
#   awk '$3 == "nfs" { print $2 " maps to " $1 }' /proc/mounts
cat /proc/mounts | while read src dest type opts rest; do
  if [[ ${type} == "nfs" ]]; then
    echo "NFS ${dest} maps to ${src}"
  fi
done
```

## 名称约定

### 函数名

小写，下划线分割单词，通过::来分割库名，函数名后的括号是必须的，关键字function是可选的，但是必须在整个项目中保持一致．如果你写一个函数，使用小写，并且按照下划线分割单词，如果你写一个包，使用::分割包名，左花括号和函数名在同一行(和其它语言的google code style一样)，函数名称和括号之间没有空格．

```
# Single function
my_func() {
  ...
}

# Part of a package
mypackage::my_func() {
  ...
}
```

在括号在函数名称之后出现，那么function这个关键字就是可选的了，其目的增强了对函数的快速识别．

### 变量名

和函数名规则相同 
在循环中的变量名应该和要循环的变量名相似． 
例子:

```
for zone in ${zones}; do
  something_with "${zone}"
done
```

### 常量和环境变量名

所有的大写变量名按照下划线分割，声明在文件的开始处 
常量和任何导出的环境变量应该大写． 
例子:

```
# Constant
readonly PATH_TO_FILES='/some/path'

# Both constant and environment
# declare -r设置只读变量，-x设置为环境变量
declare -xr ORACLE_SID='PROD' 
```

有些情况，变量需要在第一次被设置的时候，称为常量(例如 使用getopts这种情况下)，当然在getopts中基于某些条件来设置常量是很正常的，但是你需要在设置完成后立即让其变成只读的，你需要注意的是，declare不能在函数内部操作全局变量，这个时候推荐受用readonly和export来代替． 
例子:

```
VERBOSE='false'
while getopts 'v' flag; do
  case "${flag}" in
    v) VERBOSE='true' ;;
  esac
done
readonly VERBOSE
```

### 源文件名

小写并且按照下划线分割 
这与其它的google code style是一致的，maketemplate 或 make_template而不是make-template．

### 只读变量

使用readonly或declare -r确保变量是只读的．全局变量在shell中广泛使用，当使用这些全局变量的时候捕获错误是很重要的，当你声明一个变量，该变量是只读的，那么请显示声明它． 
例子:

```
zip_version="$(dpkg --status zip | grep Version: | cut -d ' ' -f 2)"
if [[ -z "${zip_version}" ]]; then
  error_message
else
  readonly zip_version
fi
```

### 本地变量

使用local声明一个局部变量.声明和赋值应该在不同的行．当使用local声明本地变量的时候，确保仅仅在函数内部可见，可以避免污染全局命名空间，和因为不经意的设置变量导致一些意外的功能．当通过命令替换给一个变量赋值的时候，必须将变量的声明和赋值分开，因为local内置命令不从命令替换传播退出码．

例子:

```
my_func2() {
  local name="$1"

  # Separate lines for declaration and assignment:
  local my_var
  my_var="$(my_func)" || return

  # DO NOT do this: $? contains the exit code of 'local', not my_func
  local my_var="$(my_func)"  #local不会把my_func的退出码传递出去
  [[ $? -eq 0 ]] || return

  ...
}
```

### 函数位置

把所有的函数放在常量的下面，不要在函数之间隐藏可执行的代码．如果你要定义一个函数，请将这个函数放在文件的开始处，在函数声明之前只能包括set语句，还有常量的设置．不要在函数之间隐藏可执行的语句，这样是的代码难以跟踪和调试，结果令人意外．

### main

对于足够长的脚本来说，至少需要一个名为main的函数来调用其它的函数． 
为了便于找到程序的开始，把主程序放在一个叫main的函数中，放在其它函数的下面，为了提供一致性你应该定义更多的变量为本地变量(如果主程序不是一个程序，那么不能这么做)，文件中一句非注释行应该是一个main函数的调用．　 
例子:

```
main "$@"
```

显然，对于短脚本来说，程序都是线性的，main函数在这里是不必要的，所以不需要．

## 命令调用

### 检查返回值

总是应该检查返回值，给出返回值相关的信息． 
对于一个未使用管道的命令，可以使用$?或者直接指向if语句来检查其返回值 
例子:

```
if ! mv "${file_list}" "${dest_dir}/" ; then
  echo "Unable to move ${file_list} to ${dest_dir}" >&2
  exit "${E_BAD_MOVE}"
fi

# Or
mv "${file_list}" "${dest_dir}/"
if [[ "$?" -ne 0 ]]; then
  echo "Unable to move ${file_list} to ${dest_dir}" >&2
  exit "${E_BAD_MOVE}"
fi
```

Bash同样有PIPESTATUE变量允许检查管道命令所有部分的返回码，这仅仅用于检查整个管道执行成功与否．下面的例子是被接受的． 
例子:

```
tar -cf - ./* | ( cd "${dir}" && tar -xf - )
if [[ "${PIPESTATUS[0]}" -ne 0 || "${PIPESTATUS[1]}" -ne 0 ]]; then
  echo "Unable to tar files to ${dir}" >&2
fi
```

然后当你使用任何其它命令的时候PIPESTATUS将会被覆盖，如果你需要根据管道发生错误的地方来进行不同的操作，那么你将需要在运行完管道命令后立即将PIPESTATUS的值赋给另外一个变量(不要忘了`[`这个符号也是一个命令，将会把PIPESTATUS的值给覆盖掉．) 
例子:

```
tar -cf - ./* | ( cd "${DIR}" && tar -xf - )
return_codes=(${PIPESTATUS[*]})
if [[ "${return_codes[0]}" -ne 0 ]]; then
  do_something
fi
if [[ "${return_codes[1]}" -ne 0 ]]; then
  do_something_else
fi
```

### 内置命令 vs 外部命令

调用shell内置命令和调用一个单独的进程在两者这件做出选择，选择调用内置命令． 
我更喜欢使用内置命令，例如函数参数扩展 (bash(1)),它更加健壮和便携．(尤其和像sed想比较而言) 
例子:

```
# Prefer this:
addition=$((${X} + ${Y}))
substitution="${string/#foo/bar}"

# Instead of this:
addition="$(expr ${X} + ${Y})"
substitution="$(echo "${string}" | sed -e 's/^foo/bar/')"
```

## 总结

达成shell使用的共识和代码保持一致． 
请花几分钟阅读下google code style C++ Guide的Parting words章节.

## 附录

[Google Code Style](https://github.com/google/styleguide) 
[Shell Style Guide](http://google.github.io/styleguide/shell.xml) 
[Google Code Style部分中文版](http://zh-google-styleguide.readthedocs.org/en/latest/)