#!/bin/bash

# 对PS4赋值，定制-x选项的提示符，T:时间，L:行号，S:脚本，F:函数调用堆栈(反序)。shell调试信息最多为99字符，函数调用太多，堆栈太长，会出现意外截断的问题。为了保持美观，将格式设置为"+[94个字符的内容]: "，最终长度即为94+5=99##
# Set the bash debug info style to pretty format. +[T: <Time>, L: <LineNumber>, S: <ScriptName>, F: <Function>]##
# 设置bash的调试信息为漂亮的格式。+[T: <Time>, L: <LineNumber>, S: <ScriptName>, F: <Function>]##
export PS4='+[$(debug_info=$(printf "T: %s, L:%3s, S: %s, F: %s" "$(date +%H%M%S)" "$LINENO" "$(basename $BASH_SOURCE)" "$(for ((i=${#FUNCNAME[*]}-1; i>=0; i--)) do func_stack="$func_stack ${FUNCNAME[i]}"; done; echo $func_stack)") && echo ${debug_info:0:94})]: '

BASE_PATH=$(readlink -m $0)
BASE_DIR=$(dirname $BASE_PATH)
BASE_NAME=$(basename $BASE_PATH .sh)

function help()
{
    echo "Usage:"
    echo "  sh $0 start [java_pid]"
    echo "  sh $0 check [java_pid]"
    echo "  sh $0 dump [java_pid]"
    echo "  sh $0 stop [java_pid]"
    exit 1
}

function run_tool_with_java_user()
{
    local run_tool=$@

    # jdk提供的工具执行时必须保证当前操作系统用户和java进程用户一致，否则会报错。##
    java_user=$(ps -eww -o pid,user:20,cmd | grep -v grep | grep java | grep -w $java_pid | awk '{print $2}')
    cur_user=$(whoami)
    if [ "$java_user" != "$cur_user" ]; then
        echo "Current os user[ $cur_user ] and java process user[ $java_user ] don't match. Now switch the user to [ $java_user ]."

        # 检查java用户是否对此工具目录有访问权限。##
        su - $java_user -c "cd $BASE_DIR" >/dev/null 2>&1
        [ $? -ne 0 ] && echo "User [ $java_user ] has no access to dir [ $BASE_DIR ]." && exit 1

        su - $java_user -c "$run_tool"
    else
        $run_tool
    fi

    echo
    echo
}

chmod -R 755 $BASE_DIR >/dev/null 2>&1

# 参数检查。##
[ $# -ne 2 ] && help
jfr_operation=$1
java_pid=$2

# 检查输入的进程是否合法。##
ps -eww -o pid,user:20,cmd | grep -v grep | grep java | awk '{print $1}' | grep -w $java_pid >/dev/null 2>&1
[ $? -ne 0 ] && echo "Pid [ $java_pid ] is not a valid java pid." | tee -a $log && exit 1

# 检查对应版本的jdk类库是否存在。##
JAVA_CMD_FOR_TOOLS=$(readlink -m /proc/$java_pid/exe)
java_version=$($JAVA_CMD_FOR_TOOLS -version 2>&1 | grep 'java version' | awk -F'"' '{print $2}' | awk -F'_' '{print $1}')
[ ! -d $BASE_DIR/lib/jdk${java_version}_* ] && echo "Find no jdk lib dir [ $BASE_DIR/lib/jdk${java_version}_* ] for java $($JAVA_CMD_FOR_TOOLS -version 2>&1 | grep 'java version' | awk -F'"' '{print $2}')." && exit 1

echo "Tips:"
echo "  Java Flight Recorder is available in JDK 7u4 and later"
echo "  Prior to JDK 8u40 release, the JVM must also have been started with the flag: -XX:+UnlockCommercialFeatures -XX:FlightRecorder."
echo "  Since the JDK 8u40 release, the Java Flight Recorder can be enabled during runtime."
echo
echo

case "$jfr_operation" in
    "start")
        run_tool_with_java_user "sh $BASE_DIR/bin/jcmd.sh $java_pid VM.unlock_commercial_features"

        run_tool_with_java_user "sh $BASE_DIR/bin/jcmd.sh $java_pid JFR.check" | grep -q $BASE_NAME
        [ $? -eq 0 ] && echo "A java flight recording task is running. No need to start again." && exit 0

        run_tool_with_java_user "sh $BASE_DIR/bin/jcmd.sh $java_pid JFR.start name=$BASE_NAME settings=profile maxsize=100m maxage=24h"
        ;;

    "check")
        run_tool_with_java_user "sh $BASE_DIR/bin/jcmd.sh $java_pid VM.unlock_commercial_features"
        run_tool_with_java_user "sh $BASE_DIR/bin/jcmd.sh $java_pid JFR.check"
        ;;

    "dump")
        hostname=$(hostname)
        ips=$(ifconfig -a | grep -w 'inet' | awk -F: '{print $2}' | awk '{print $1}' | grep -v '127.0.0.1' | tr '\n' '-' | sed 's/-$//g')
        date=$(date "+%Y%m%dT%H%M%S%z")
        jrf_file=/tmp/${BASE_NAME}_${hostname}_${ips}_${date}.jfr

        run_tool_with_java_user "sh $BASE_DIR/bin/jcmd.sh $java_pid VM.unlock_commercial_features"
        run_tool_with_java_user "sh $BASE_DIR/bin/jcmd.sh $java_pid JFR.dump name=$BASE_NAME filename=$jrf_file compress=true"
        ;;

    "stop")
        run_tool_with_java_user "sh $BASE_DIR/bin/jcmd.sh $java_pid VM.unlock_commercial_features"
        run_tool_with_java_user "sh $BASE_DIR/bin/jcmd.sh $java_pid JFR.stop name=$BASE_NAME"
        ;;

    *)
        help
        ;;
esac

echo
echo

