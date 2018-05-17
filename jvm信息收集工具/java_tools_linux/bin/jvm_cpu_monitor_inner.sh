#!/bin/bash

# 对PS4赋值，定制-x选项的提示符，T:时间，L:行号，S:脚本，F:函数调用堆栈(反序)。shell调试信息最多为99字符，函数调用太多，堆栈太长，会出现意外截断的问题。为了保持美观，将格式设置为"+[94个字符的内容]: "，最终长度即为94+5=99##
# Set the bash debug info style to pretty format. +[T: <Time>, L: <LineNumber>, S: <ScriptName>, F: <Function>]##
# 设置bash的调试信息为漂亮的格式。+[T: <Time>, L: <LineNumber>, S: <ScriptName>, F: <Function>]##
export PS4='+[$(debug_info=$(printf "T: %s, L:%3s, S: %s, F: %s" "$(date +%H%M%S)" "$LINENO" "$(basename $BASH_SOURCE)" "$(for ((i=${#FUNCNAME[*]}-1; i>=0; i--)) do func_stack="$func_stack ${FUNCNAME[i]}"; done; echo $func_stack)") && echo ${debug_info:0:94})]: '

BASE_PATH=$(readlink -m $0)
BASE_DIR=$(dirname $BASE_PATH)
BASE_NAME=$(basename $BASE_PATH .sh)

if [ $# -eq 1 ]; then
    pid=$1

    hostname=$(hostname)
    ips=$(ifconfig -a | grep -w 'inet' | awk -F: '{print $2}' | awk '{print $1}' | grep -v '127.0.0.1' | tr '\n' '-' | sed 's/-$//g')
    date=$(date "+%Y%m%dT%H%M%S%z")

    collection_dir=/tmp/${BASE_NAME}_${hostname}_${ips}_${date}

elif [ $# -eq 2 ]; then
    pid=$1
    collection_dir=$2
else
    echo "Usage: sh $0 <java_pid> [output_dir]"
    exit 1
fi

log=$collection_dir/${BASE_NAME}.log
mkdir -p $collection_dir

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

# java线程堆栈中的本地线程显示为16进制，而top命令中的线程为10进制，为了方便比对，在top文件中添加16进制的线程ID##
function add_pid16_to_top_file()
{
    local top_file=$1
    # 若第一列为数字，则在前面添加16进制的数字。若第一列为PID，则在前面添加PID-16。其他情况原样输出##
    awk '{if($1~/^[0-9]+$/) {printf("0x%x %s\n",$1,$0)} else if($1~/^PID$/) {printf("PID-16 %s\n",$0)} else {printf("%s\n",$0)}}' $top_file >$top_file.tmp
    mv $top_file.tmp $top_file
}

# 根据进程id获得java路径##
export JAVA_CMD_FOR_TOOLS=$(readlink -m /proc/$pid/exe)

print_info "============================================================================================"
print_info "获取java虚拟机线程转储："
print_info "Get stack info."
print_info "============================================================================================"

# 检查CPU的次数##
check_cpu_times=10000
# 检查CPU的的间隔，建议不要小于2s##
check_cpu_interval=2s
# cpu占用率阈值(单位：百分比%)，超过时才获取线程堆栈。特别地0.0表示一直获取堆栈##
cpu_threshold_usage=20
# cpu占用率持续次数阈值，只有持续次数大于次数阈值时，才获取线程堆栈##
cpu_threshold_times=5

# 获取线程堆栈的次数，一次性的连续获取多次线程堆栈，供分析比较，推荐3次##
stack_times=3
# 获取线程堆栈的间隔，建议不要小于2s##
stack_interval=2s


cpu_high_continuous_times=0
for check_cpu_time in $(seq -f "%05g" 1 $check_cpu_times)
do
    print_info "Check cpu time $check_cpu_time of $(seq -f "%05g" 1 $check_cpu_times | tail -1)."
    print_info "The target dir is [ $collection_dir ]."

    # 风险：top命令执行时间过长，一般需要0.5秒，所有获取线程堆栈的间隔不要太小，以免对检查周期产生较大影响。##
    cpu_usage=$(top -b -n 1 -p $pid | grep -w $pid | awk '{print $9}')
    if [ $(echo "$cpu_usage < $cpu_threshold_usage" | bc) -eq 1 ]; then
        cpu_high_continuous_times=0
        print_info "Beacuse {cpu_usage} [$cpu_usage%] < {cpu_threshold_usage} [$cpu_threshold_usage%], reset {cpu_high_continuous_times} to [$cpu_high_continuous_times]."
        print_info "Beacuse {cpu_high_continuous_times} [$cpu_high_continuous_times] < {cpu_threshold_times} [$cpu_threshold_times], skip to get stack this time."
        print_info "Sleep $check_cpu_interval ..."
        sleep $check_cpu_interval
        echo | tee -a $log
        continue
    fi

    ((cpu_high_continuous_times++))
    print_info "Beacuse {cpu_usage} [$cpu_usage%] >= {cpu_threshold_usage} [$cpu_threshold_usage%], increase {cpu_high_continuous_times} to [$cpu_high_continuous_times]."

    if [ $cpu_high_continuous_times -lt $cpu_threshold_times ]; then
        print_info "Beacuse {cpu_high_continuous_times} [$cpu_high_continuous_times] < {cpu_threshold_times} [$cpu_threshold_times], skip to get stack this time."
        print_info "Sleep $check_cpu_interval ..."
        sleep $check_cpu_interval
        echo | tee -a $log
        continue
    fi

    print_info "Beacuse {cpu_high_continuous_times} [$cpu_high_continuous_times] >= {cpu_threshold_times} [$cpu_threshold_times], start to get stack this time."
    for stack_time in $(seq 1 $stack_times)
    do
        print_info "Get stack time $stack_time of $(seq 1 $stack_times | tail -1)."

        print_info "Exec cmd [ sh $BASE_DIR/jstack.sh -l $pid ]."
        sh $BASE_DIR/jstack.sh -l $pid >$collection_dir/$check_cpu_time-jstack-$stack_time.txt

        print_info "Exec cmd [ gstack $pid ]."
        gstack $pid                    >$collection_dir/$check_cpu_time-pstack-$stack_time.txt

        print_info "Exec cmd [ top -bcH -n 1 -p $pid ]."
        top -bcH -n 1 -p $pid          >$collection_dir/$check_cpu_time-top-$stack_time.txt

        print_info "Add PID-16 column to top file."
        add_pid16_to_top_file           $collection_dir/$check_cpu_time-top-$stack_time.txt

        print_info "Sleep $stack_interval ..."
        sleep $stack_interval
        echo | tee -a $log
    done

    cpu_high_continuous_times=0
    print_info "Finish to get stack, reset {cpu_high_continuous_times} to [$cpu_high_continuous_times]."
    print_info "Sleep $check_cpu_interval ..."
    sleep $check_cpu_interval
    echo | tee -a $log
done
echo | tee -a $log
echo | tee -a $log

print_info "============================================================================================"
print_info "压缩目录："
print_info "zip -r $collection_dir.zip $collection_dir"
print_info "============================================================================================"
zip -r $collection_dir.zip $collection_dir | tee -a $log
echo | tee -a $log
echo | tee -a $log

print_info "============================================================================================"
print_info "显示目录大小："
print_info "du -ah $collection_dir* | sort -k 2 | column -t"
print_info "============================================================================================"
du -ah $collection_dir* | sort -k 2 | column -t | tee -a $log
echo | tee -a $log
echo | tee -a $log

echo "The target file is [ $collection_dir.zip ]." | tee -a $log
echo | tee -a $log
echo | tee -a $log

