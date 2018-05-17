#!/bin/bash

# Set the debug info style to pretty format. +[T: <Time>, L: <LineNumber>, S: <ScriptName>, F: <Function>]##
export PS4='+[$(debug_info=$(printf "T: %s, L:%3s, S: %s, F: %s" "$(date +%H%M%S)" "$LINENO" "$(basename "${BASH_SOURCE[0]}")" "$(for ((i=${#FUNCNAME[*]}-1; i>=0; i--)) do func_stack="$func_stack ${FUNCNAME[i]}"; done; echo $func_stack)") && echo ${debug_info:0:94})]: '

SCRIPT="$0"
# Get the absolute path of the script.##
# SCRIPT may be an arbitrarily deep series of symlinks. Loop until we have the concrete path.##
while [ -h "$SCRIPT" ] ; do
	ls=`ls -ld "$SCRIPT"`
	# Drop everything prior to ->
	link=`expr "$ls" : '.*-> \(.*\)$'`
	if expr "$link" : '/.*' > /dev/null; then
		SCRIPT="$link"
	else
		SCRIPT=`dirname "$SCRIPT"`/"$link"
	fi
done

SH_DIR=$(cd $(dirname $SCRIPT); pwd)
SH_NAME=$(basename $SCRIPT .sh)

log=$SH_DIR/$SH_NAME.log

function write_log()
{
	[ -n "$@" ] && echo "[`date "+%F %T"`] $@" >>$log
}

function print_log()
{
	[ -n "$@" ] && echo "$@"
	[ -n "$@" ] && echo "[`date "+%F %T"`] $@" >>$log
}

function die()
{
	print_log "$@"
	print_log "See log [$log]"
	exit 1
}

[ $# -eq 0 ] && echo "Usage: sh $0 <path...>" && exit 1
search_path="$@"
# search_path="${OMU_HOME}/run ${DMU_HOME}/repository"##

# 旧包目录存在且不为空，备份此目录##
[ -d "$SH_DIR/old" ] && [ -n "$(ls -A $SH_DIR/old)" ] && mv $SH_DIR/old $SH_DIR/old_`date +%Y%m%d%H%M%S`

mkdir -p $SH_DIR/new
mkdir -p $SH_DIR/old

>$SH_DIR/new_jar_path.txt
>$SH_DIR/new_war_path.txt
>$SH_DIR/old_jar_path.txt
>$SH_DIR/old_war_packed_path.txt
>$SH_DIR/old_war_unpacked_path.txt

find $SH_DIR/new -type f -name "*.jar" >$SH_DIR/new_jar_path.txt
find $SH_DIR/new -type f -name "*.war" >$SH_DIR/new_war_path.txt

# 处理jar包##
while read new_jar_path
do
	# 为了让如下的两个包能够匹配，需要对版本标记进行预处理，使用通配符搜索##
	# com.xdc.soft-1.0.0-SNAPSHOT.jar##
	# com.xdc.soft-1.0.0-20160314.123852-178.jar##

	new_jar_name=$(basename $new_jar_path)
	new_jar_name_wildcard=$(echo $new_jar_name | sed 's/-SNAPSHOT.jar/-*.jar/')
	new_jar_name_wildcard=$(echo $new_jar_name_wildcard | sed 's/-[0-9]*.[0-9]*-[0-9]*.jar/-*.jar/')

	find_jar_para="$find_jar_para -o -type f -name $new_jar_name_wildcard"
done <$SH_DIR/new_jar_path.txt

if [ -n "$find_jar_para" ]; then
	find_jar_cmd="find $search_path ${find_jar_para#*-o}"
	`$find_jar_cmd >$SH_DIR/old_jar_path.txt`

	# 替换jar包##
	while read new_jar_path
	do
		new_jar_name=$(basename $new_jar_path)
		new_jar_name_wildcard=$(echo $new_jar_name | sed 's/-SNAPSHOT.jar/-*.jar/')
		new_jar_name_wildcard=$(echo $new_jar_name_wildcard | sed 's/-[0-9]*.[0-9]*-[0-9]*.jar/-*.jar/')

		echo "-----------------------------------------------------------------------"
		echo "Handling $new_jar_name"
		echo "-----------------------------------------------------------------------"
		while read old_jar_path
		do
			old_jar_name=$(basename $old_jar_path)
			old_jar_name_wildcard=$(echo $old_jar_name | sed 's/-SNAPSHOT.jar/-*.jar/')
			old_jar_name_wildcard=$(echo $old_jar_name_wildcard | sed 's/-[0-9]*.[0-9]*-[0-9]*.jar/-*.jar/')

			if [ "${new_jar_name_wildcard}" = "${old_jar_name_wildcard}" ]; then
				echo "replace to: $old_jar_path"
				cp $old_jar_path $SH_DIR/old/$old_jar_name
				cp $new_jar_path $old_jar_path
			fi
		done <$SH_DIR/old_jar_path.txt
		echo
	done <$SH_DIR/new_jar_path.txt
fi


# 处理war包##
while read new_war_path
do
	new_war_name=$(basename $new_war_path)
	find_war_packed_para="$find_war_packed_para -o -type f -name $new_war_name"
	find_war_unpacked_para="$find_war_unpacked_para -o -type d -name ${new_war_name%.*}"
done <${SH_DIR}/new_war_path.txt

if [ -n "$find_war_packed_para" -a -n "$find_war_unpacked_para" ]; then
	find_war_packed_cmd="find $search_path ${find_war_packed_para#*-o}"
	`$find_war_packed_cmd >$SH_DIR/old_war_packed_path.txt`

	find_war_unpacked_cmd="find $search_path ${find_war_unpacked_para#*-o}"
	`$find_war_unpacked_cmd >$SH_DIR/old_war_unpacked_path.txt`

	while read new_war_path
	do
		new_war_name=$(basename $new_war_path)
		echo "-----------------------------------------------------------------------"
		echo "Handling $new_war_name"
		echo "-----------------------------------------------------------------------"

		# 替换压缩的war包##
		while read old_war_packed_path
		do
			old_war_packed_name=$(basename $old_war_packed_path)
			if [ "$old_war_packed_name" = "$new_war_name" ]; then
				echo "replace to: $old_war_packed_path"
				cp $old_war_packed_path $SH_DIR/old/$new_war_name
				cp $new_war_path $old_war_packed_path
			fi
		done <$SH_DIR/old_war_packed_path.txt

		# 替换解压缩的war包##
		while read old_war_unpacked_path
		do
			old_war_unpacked_name=$(basename $old_war_unpacked_path)
			if [ "$old_war_unpacked_name" = "${new_war_name%.war}" ]; then
				echo "replace to: ${old_war_unpacked_path}"
				user=`ls -l -d $old_war_unpacked_path | awk '{print $3}'`
				group=`ls -l -d $old_war_unpacked_path | awk '{print $4}'`

				`cd $old_war_unpacked_path && zip -qr $SH_DIR/old/$new_war_name ./ && rm -rf $old_war_unpacked_path`
				unzip -qo $new_war_path -d $old_war_unpacked_path
				chmod -R 770 $old_war_unpacked_path
				chown -R $user:$group $old_war_unpacked_path
			fi
		done <$SH_DIR/old_war_unpacked_path.txt
		echo
	done <$SH_DIR/new_war_path.txt
fi

