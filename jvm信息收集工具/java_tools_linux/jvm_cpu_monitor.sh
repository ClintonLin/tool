#!/bin/bash

# 对PS4赋值，定制-x选项的提示符，T:时间，L:行号，S:脚本，F:函数调用堆栈(反序)。shell调试信息最多为99字符，函数调用太多，堆栈太长，会出现意外截断的问题。为了保持美观，将格式设置为"+[94个字符的内容]: "，最终长度即为94+5=99##
# Set the bash debug info style to pretty format. +[T: <Time>, L: <LineNumber>, S: <ScriptName>, F: <Function>]##
# 设置bash的调试信息为漂亮的格式。+[T: <Time>, L: <LineNumber>, S: <ScriptName>, F: <Function>]##
export PS4='+[$(debug_info=$(printf "T: %s, L:%3s, S: %s, F: %s" "$(date +%H%M%S)" "$LINENO" "$(basename $BASH_SOURCE)" "$(for ((i=${#FUNCNAME[*]}-1; i>=0; i--)) do func_stack="$func_stack ${FUNCNAME[i]}"; done; echo $func_stack)") && echo ${debug_info:0:94})]: '

BASE_PATH=$(readlink -m $0)
BASE_DIR=$(dirname $BASE_PATH)
BASE_NAME=$(basename $BASE_PATH .sh)

hostname=$(hostname)
ips=$(ifconfig -a | grep -w 'inet' | awk -F: '{print $2}' | awk '{print $1}' | grep -v '127.0.0.1' | tr '\n' '-' | sed 's/-$//g')
date=$(date "+%Y%m%dT%H%M%S%z")

collection_dir=/tmp/${BASE_NAME}_${hostname}_${ips}_${date}
log=$collection_dir/${BASE_NAME}.log

function print_error()
{
    [ -n "$@" ] && echo "[`date "+%F %T"`] ERROR: $@" | tee -a $log
}

function print_info()
{
    [ -n "$@" ] && echo "[`date "+%F %T"`] INFO: $@" | tee -a $log
}

function log_error()
{
    [ -n "$@" ] && echo "[`date "+%F %T"`] ERROR: $@" >>$log
}

function log_info()
{
    [ -n "$@" ] && echo "[`date "+%F %T"`] INFO: $@" >>$log
}

function die()
{
    print_error "$@"
    print_error "See log [$log] for details."
    exit 1
}

chmod -R 755 $BASE_DIR >/dev/null 2>&1

mkdir -p $collection_dir
chmod -R 777 $collection_dir

# print_info "============================================================================================"
# print_info "sh $BASE_DIR/bin/jps.sh -mlv"
# print_info "============================================================================================"
# sh $BASE_DIR/bin/jps.sh -mlv | tee -a $log
# echo | tee -a $log
# echo | tee -a $log

print_info "============================================================================================"
print_info "查询java进程："
print_info "ps -eww -o pid,user:20,cmd | grep -v grep | grep java"
print_info "============================================================================================"
# 查询java进程。##
ps -eww -o pid,user:20,cmd | head -n1                                                    | tee -a $log
ps -eww -o pid,user:20,cmd | grep -v grep | grep java | grep -v tee | grep -v $BASE_NAME | tee -a $log
echo | tee -a $log
echo | tee -a $log

# 选择java进程。##
read -p "Enter java pid: " pid
echo "You enter: $pid" | tee -a $log
echo | tee -a $log
echo | tee -a $log
[ -z "$pid" ] && echo "Pid can not be empty." | tee -a $log && exit 1

# 检查输入的进程是否合法。##
ps -eww -o pid,user:20,cmd | grep -v grep | grep java | awk '{print $1}' | grep -w $pid >/dev/null 2>&1
[ $? -ne 0 ] && echo "Pid [ $pid ] is not a valid java pid." | tee -a $log && exit 1

# 检查对应版本的jdk类库是否存在。##
JAVA_CMD_FOR_TOOLS=$(readlink -m /proc/$pid/exe)
java_version=$($JAVA_CMD_FOR_TOOLS -version 2>&1 | grep 'java version' | awk -F'"' '{print $2}' | awk -F'_' '{print $1}')
[ ! -d $BASE_DIR/lib/jdk${java_version}_* ] && echo "Find no jdk lib dir [ $BASE_DIR/lib/jdk${java_version}_* ] for java $($JAVA_CMD_FOR_TOOLS -version 2>&1 | grep 'java version' | awk -F'"' '{print $2}')." | tee -a $log && exit 1

# jdk提供的工具执行时必须保证当前操作系统用户和java进程用户一致，否则会报错。##
java_user=$(ps -eww -o pid,user:20,cmd | grep -v grep | grep java | grep -w $pid | awk '{print $2}')
cur_user=$(whoami)
if [ "$java_user" != "$cur_user" ]; then
    echo "Current os user[ $cur_user ] and java process user[ $java_user ] don't match. Now switch the user to [ $java_user ]." | tee -a $log
    echo | tee -a $log
    echo | tee -a $log

    # 检查java用户是否对此工具目录有访问权限。##
    su - $java_user -c "cd $BASE_DIR" >/dev/null 2>&1
    [ $? -ne 0 ] && echo "User [ $java_user ] has no access to dir [ $BASE_DIR ]." | tee -a $log && exit 1

    su - $java_user -c "sh $BASE_DIR/bin/jvm_cpu_monitor_inner.sh $pid $collection_dir" | tee -a $log
else
    sh $BASE_DIR/bin/jvm_cpu_monitor_inner.sh $pid $collection_dir | tee -a $log
fi

echo | tee -a $log
echo | tee -a $log

