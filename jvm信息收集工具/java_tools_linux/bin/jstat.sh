#!/bin/bash

# 对PS4赋值，定制-x选项的提示符，T:时间，L:行号，S:脚本，F:函数调用堆栈(反序)。shell调试信息最多为99字符，函数调用太多，堆栈太长，会出现意外截断的问题。为了保持美观，将格式设置为"+[94个字符的内容]: "，最终长度即为94+5=99##
# Set the bash debug info style to pretty format. +[T: <Time>, L: <LineNumber>, S: <ScriptName>, F: <Function>]##
# 设置bash的调试信息为漂亮的格式。+[T: <Time>, L: <LineNumber>, S: <ScriptName>, F: <Function>]##
export PS4='+[$(debug_info=$(printf "T: %s, L:%3s, S: %s, F: %s" "$(date +%H%M%S)" "$LINENO" "$(basename $BASH_SOURCE)" "$(for ((i=${#FUNCNAME[*]}-1; i>=0; i--)) do func_stack="$func_stack ${FUNCNAME[i]}"; done; echo $func_stack)") && echo ${debug_info:0:94})]: '

BASE_PATH=$(readlink -m $0)
BASE_DIR=$(dirname $BASE_PATH)
BASE_NAME=$(basename $BASE_PATH .sh)

log=$BASE_DIR/$BASE_NAME.log

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

function get_target_java_pid()
{
    for arg in $(echo $@)
    do
        # 分析了jdk的工具集，第一个数字参数即为java的pid。##
        (echo $arg | grep -w '^[0-9][0-9]*$' >/dev/null 2>&1) && echo $arg && return 0
    done
}

function check_target_java_pid()
{
    # 如果参数中不存在target_java_pid，则不进行检查。正常的jdk工具使用过程中是有不输入参数的场景的，例如使用无参数的jps查询当前运行的所有java进程。##
    target_java_pid=$(get_target_java_pid $@)
    [ -z "$target_java_pid" ] && return 0

    # 检查pid是否合法。##
    ps -ww -o pid,user:20,cmd -p $target_java_pid | sed '1d' | awk '{print $3}' | grep -w java >/dev/null 2>&1
    [ $? -ne 0 ] && echo "Pid [ $target_java_pid ] is not a valid java pid." && exit 1

    # jdk提供的工具执行时必须保证当前操作系统用户和java进程用户一致，否则会报错。##
    java_user=$(ps -ww -o pid,user:20,cmd -p $target_java_pid | sed '1d' | awk '{print $2}')
    cur_user=$(whoami)
    [ "$java_user" != "$cur_user" ] && echo "Current os user[ $cur_user ] and java process user[ $java_user ] don't match. Please switch the user to [ $java_user ]." && exit 1
}

function set_java_env()
{
    # 设置JAVA_CMD_FOR_TOOLS：如果参数中存在target_java_pid，则优先使用target_java_pid获取java执行程序路径进行设置JAVA_CMD_FOR_TOOLS，否则以环境变量中的JAVA_CMD_FOR_TOOLS为准，如果JAVA_CMD_FOR_TOOLS仍然为空，则提示设置环境变量。##
    target_java_pid=$(get_target_java_pid $@)
    [ -n "$target_java_pid" ] && JAVA_CMD_FOR_TOOLS=$(readlink -m /proc/$target_java_pid/exe)

    # 检查变量JAVA_CMD_FOR_TOOLS是否设置。##
    if [ -z "$JAVA_CMD_FOR_TOOLS" ]; then
        # 查找正在运行的java进程。##
        java_processes=$(ps -eww -o pid,user:20,cmd | grep -v grep | grep java)
        [ -z "$java_processes" ] && echo "Find no running java process." && exit 1

        # 提示设置JAVA_CMD_FOR_TOOLS。##
        echo "Env [ JAVA_CMD_FOR_TOOLS ] not set. Please Set env first by using one of the following commands: "
        printf "%-10s %-20s %s\n" "PID" "USER" "SET_JAVA_ENV_COMMAND"
        echo "$java_processes" |  while read java_process
        do
            java_process_id=$(echo $java_process | awk '{print $1}')
            java_process_user=$(echo $java_process | awk '{print $2}')
            java_process_executable=$(readlink -m /proc/$java_process_id/exe)
            printf "%-10s %-20s [ export JAVA_CMD_FOR_TOOLS=%s ]\n" "$java_process_id" "$java_process_user" "$java_process_executable"
        done
        exit 1
    fi

    # 使用对应版本的jdk类库建立链接。##
    java_version=$($JAVA_CMD_FOR_TOOLS -version 2>&1 | grep 'java version' | awk -F'"' '{print $2}' | awk -F'_' '{print $1}')
    [ ! -d $BASE_DIR/../lib/jdk${java_version}_* ] && echo "Find no jdk lib dir [ $BASE_DIR/../lib/jdk${java_version}_* ] for java $($JAVA_CMD_FOR_TOOLS -version 2>&1 | grep 'java version' | awk -F'"' '{print $2}')." && exit 1
    JDK_LIB_DIR_FOR_TOOLS=$(ls -d $BASE_DIR/../lib/jdk${java_version}_*)
}

check_target_java_pid $@
set_java_env $@

$JAVA_CMD_FOR_TOOLS -Djava.library.path=$JDK_LIB_DIR_FOR_TOOLS -classpath $JDK_LIB_DIR_FOR_TOOLS/tools.jar sun.tools.jstat.Jstat $@

