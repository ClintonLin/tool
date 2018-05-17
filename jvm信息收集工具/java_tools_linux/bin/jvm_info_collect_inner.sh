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
print_info "查询java版本："
print_info "$JAVA_CMD_FOR_TOOLS -version"
print_info "============================================================================================"
$JAVA_CMD_FOR_TOOLS -version 2>&1 | tee -a $log
echo | tee -a $log
echo | tee -a $log

print_info "============================================================================================"
print_info "查询java进程运行时间："
print_info "sh $BASE_DIR/jcmd.sh $pid VM.uptime"
print_info "============================================================================================"
sh $BASE_DIR/jcmd.sh $pid VM.uptime | tee -a $log
echo | tee -a $log
echo | tee -a $log

print_info "============================================================================================"
print_info "查询java虚拟机系统属性："
print_info "sh $BASE_DIR/jcmd.sh $pid VM.system_properties"
print_info "============================================================================================"
sh $BASE_DIR/jcmd.sh $pid VM.system_properties | tee -a $log
echo | tee -a $log
echo | tee -a $log

print_info "============================================================================================"
print_info "查询java虚拟机启动参数："
print_info "sh $BASE_DIR/jcmd.sh $pid VM.command_line"
print_info "============================================================================================"
sh $BASE_DIR/jcmd.sh $pid VM.command_line | tee -a $log
echo | tee -a $log
echo | tee -a $log

print_info "============================================================================================"
print_info "显示java虚拟机GC信息(按大小显示)："
print_info "sh $BASE_DIR/jstat.sh -gc $pid 1000 3"
print_info "============================================================================================"
# 此操作要放在"获取java虚拟机堆转储"和"显示堆中存活对象统计信息的直方图"的前面，以免这个两个操作触发的GC影响显示GC信息的结果。##
sh $BASE_DIR/jstat.sh -gc $pid 1000 3 | tee -a $log
echo "输出内容含义如下(中文)：                                      " | tee -a $log
echo "  S0C  新生代存活区Survivor0区容量(单位KB)。                  " | tee -a $log
echo "  S1C  新生代存活区Survivor1区容量(单位KB)。                  " | tee -a $log
echo "  S0U  新生代存活区Survivor0区占用(单位KB)。                  " | tee -a $log
echo "  S1U  新生代存活区Survivor1区占用(单位KB)。                  " | tee -a $log
echo "  EC   新生代伊甸园区Eden区容量(单位KB)。                     " | tee -a $log
echo "  EU   新生代伊甸园区Eden区占用(单位KB)。                     " | tee -a $log
echo "  OC   老年代Old区占用容量(单位KB)。                          " | tee -a $log
echo "  OU   老年代Old区占用占用(单位KB)。                          " | tee -a $log
echo "  PC   永久代Permanent区容量(单位KB)。(注：before java 1.8)   " | tee -a $log
echo "  PU   永久代Permanent区占用(单位KB)。(注：before java 1.8)   " | tee -a $log
echo "  MC   元数据空间容量(单位KB)。       (注：java 1.8)          " | tee -a $log
echo "  MU   元数据空间占用(单位KB)。       (注：java 1.8)          " | tee -a $log
echo "  CCSC 压缩类空间容量(单位KB)。       (注：java 1.8)          " | tee -a $log
echo "  CCSU 压缩类空间占用(单位KB)。       (注：java 1.8)          " | tee -a $log
echo "  YGC  应用程序启动后发生Young GC的次数。                     " | tee -a $log
echo "  YGCT 应用程序启动后发生Young GC所用的时间(单位秒)。         " | tee -a $log
echo "  FGC  应用程序启动后发生Full GC的次数。                      " | tee -a $log
echo "  FGCT 应用程序启动后发生Full GC所用的时间(单位秒)。          " | tee -a $log
echo "  GCT  应用程序启动后发生Young GC和Full GC所用的时间(单位秒)。" | tee -a $log
echo | tee -a $log
echo | tee -a $log

print_info "============================================================================================"
print_info "显示java虚拟机GC信息(按百分比显示)："
print_info "sh $BASE_DIR/jstat.sh -gccause $pid 1000 3"
print_info "============================================================================================"
# 此操作要放在"获取java虚拟机堆转储"和"显示堆中存活对象统计信息的直方图"的前面，以免这个两个操作触发的GC影响显示GC信息的结果。##
sh $BASE_DIR/jstat.sh -gccause $pid 1000 3 | tee -a $log
echo "输出内容含义如下(中文)：                                      " | tee -a $log
echo "  S0   新生代存活区Survivor0区占用百分比。                    " | tee -a $log
echo "  S1   新生代存活区Survivor1区占用百分比。                    " | tee -a $log
echo "  E    新生代伊甸园区Eden区占用百分比。                       " | tee -a $log
echo "  O    老年代Old区占用百分比。                                " | tee -a $log
echo "  P    永久代Permanent区占用百分比。(注：before java 1.8)     " | tee -a $log
echo "  M    元数据空间占用百分比。       (注：java 1.8)            " | tee -a $log
echo "  CCS  压缩类空间占用百分比。       (注：java 1.8)            " | tee -a $log
echo "  YGC  应用程序启动后发生Young GC的次数。                     " | tee -a $log
echo "  YGCT 应用程序启动后发生Young GC所用的时间(单位秒)。         " | tee -a $log
echo "  FGC  应用程序启动后发生Full GC的次数。                      " | tee -a $log
echo "  FGCT 应用程序启动后发生Full GC所用的时间(单位秒)。          " | tee -a $log
echo "  GCT  应用程序启动后发生Young GC和Full GC所用的时间(单位秒)。" | tee -a $log
echo "  LGCC 上次GC的原因。                                         " | tee -a $log
echo "  GCC  当前GC的原因。                                         " | tee -a $log
echo | tee -a $log
echo | tee -a $log

print_info "============================================================================================"
print_info "获取java虚拟机线程转储："
print_info "Get stack info."
print_info "============================================================================================"
# 获取线程堆栈的次数，一次性的连续获取多次线程堆栈，供分析比较，推荐3次##
stack_times=3
# 获取线程堆栈的间隔，建议不要小于2s##
stack_interval=2s
for stack_time in $(seq 1 $stack_times)
do
    print_info "Get stack time $stack_time of $(seq 1 $stack_times | tail -1)."

    print_info "Exec cmd [ sh $BASE_DIR/jstack.sh -l $pid ]."
    sh $BASE_DIR/jstack.sh -l $pid >$collection_dir/jstack-$stack_time.txt

    print_info "Exec cmd [ gstack $pid ]."
    gstack $pid                    >$collection_dir/pstack-$stack_time.txt

    print_info "Exec cmd [ top -bcH -n 1 -p $pid ]."
    top -bcH -n 1 -p $pid          >$collection_dir/top-$stack_time.txt

    print_info "Add PID-16 column to top file."
    add_pid16_to_top_file           $collection_dir/top-$stack_time.txt

    print_info "Sleep $stack_interval ..."
    sleep $stack_interval
    echo | tee -a $log
done
echo | tee -a $log
echo | tee -a $log

# print_info "============================================================================================"
# print_info "显示java进程中cpu最高的top5线程："
# print_info "$JAVA_CMD_FOR_TOOLS -Djava.library.path=$BASE_DIR/../lib -classpath $BASE_DIR/../lib/tools.jar:$BASE_DIR/jtop.jar jtop -size H -thread 5 -stack 100 --color $pid 1000 10"
# print_info "============================================================================================"
# # 显示java进程中cpu最高的top5线程，间隔2秒，打印10次##
# $JAVA_CMD_FOR_TOOLS -Djava.library.path=$BASE_DIR/../lib -classpath $BASE_DIR/../lib/tools.jar:$BASE_DIR/jtop.jar jtop -size H -thread 5 -stack 100 --color $pid 1000 10 | tee -a $log
# echo | tee -a $log
# echo | tee -a $log

print_info "============================================================================================"
print_info "查询进程的地址空间和内存状态信息："
print_info "pmap $pid"
print_info "============================================================================================"
# 进程的地址空间和内存状态信息##
pmap $pid | tee -a $log
echo | tee -a $log
echo | tee -a $log

print_info "============================================================================================"
print_info "显示堆中对象统计信息的直方图："
print_info "sh $BASE_DIR/jmap.sh -histo $pid"
print_info "============================================================================================"
sh $BASE_DIR/jmap.sh -histo $pid | tee -a $log
echo | tee -a $log
echo | tee -a $log

print_info "============================================================================================"
print_info "显示堆中存活对象统计信息的直方图："
print_info "sh $BASE_DIR/jmap.sh -histo:live $pid"
print_info "============================================================================================"
# To print histogram of java object heap; if the "live" suboption is specified, only count live objects.##
# 注意：带有live参数时，JVM会先触发Young GC，再触发Full GC，然后再统计信息。因为Full GC会暂停应用，请权衡后用。##
sh $BASE_DIR/jmap.sh -histo:live $pid | tee -a $log
echo | tee -a $log
echo | tee -a $log

print_info "============================================================================================"
print_info "获取java虚拟机堆转储："
print_info "sh $BASE_DIR/jmap.sh -dump:live,format=b,file=$collection_dir/heap_dump.hprof $pid"
print_info "============================================================================================"
# To dump java heap in hprof binary format.##
# 注意1：同histo，带有live参数时，JVM会先触发Young GC，再触发Full GC，在生成文件。##
# 注意2：JVM会将整个heap的信息dump写入到一个文件，heap如果比较大的话，就会导致这个过程比较耗时，并且执行的过程中为了保证dump的信息是可靠的，所以会暂停应用。##
sh $BASE_DIR/jmap.sh -dump:live,format=b,file=$collection_dir/heap_dump.hprof $pid | tee -a $log
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

print_info "============================================================================================"
print_info "压缩目录(已删除heapdump)："
print_info "zip -r $collection_dir.without.heapdump.zip $collection_dir"
print_info "============================================================================================"
rm $collection_dir/heap_dump.hprof
zip -r $collection_dir.without.heapdump.zip $collection_dir | tee -a $log
echo | tee -a $log
echo | tee -a $log

print_info "============================================================================================"
print_info "显示目录大小(已删除heapdump)："
print_info "du -ah $collection_dir* | sort -k 2 | column -t"
print_info "============================================================================================"
du -ah $collection_dir* | sort -k 2 | column -t | tee -a $log
echo | tee -a $log
echo | tee -a $log

echo "The target file is [ $collection_dir.zip ] and [ $collection_dir.without.heapdump.zip ]." | tee -a $log
echo | tee -a $log
echo | tee -a $log

