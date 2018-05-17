#!/bin/bash
function die
{
    echo "$@"
    exit 1
}
[ "$#" != 4 ] && die "Arguments is invalid."
APPLOADERLOGFILE=$1
[ ! -f $APPLOADERLOGFILE ] && die "Apploader.log[$APPLOADERLOGFILE] is not exists."
shift 1
THREADDUMP_LOG_DIR=$1
shift 1
ANALYSE_OUTPUT_DIR=$1
shift 1
ANALYSE_TIME=3
for $BUNDLENAME in $(echo $@)
do
    BUNDLE_REFRESH_CONTENT=$(cat $APPLOADERLOGFILE | grep "refresh" | grep "$BUNDLENAME" | tail -1)
    BUNDLE_REFRESH_TIME=$(echo $BUNDLE_REFRESH_CONTENT | awk -F"," '{print $1}')
    BUNDLE_INSTALL_TIME=$(cat $APPLOADERLOGFILE | grep "install a new" | grep "$BUNDLENAME" | tail -1 | awk -F"," '{print $1}')
    BUNDLE_INSTALL_TIME_num=$(date -d"$BUNDLE_INSTALL_TIME" +%s)
    BUNDLE_REFRESH_THREADNAME=$(echo $BUNDLE_REFRESH_CONTENT | awk -F"[" '{print $2}' | awk -F"]" '{print $1}')
    BUNDLE_WORKING_TIME="$BUNDLE_REFRESH_TIME"
    CNT_ANALYSE_TIME=0
    while [ 1 ]
    do
        if [ $CNT_ANALYSE_TIME -gt $ANALYSE_TIME ];then
            break
        fi
        BUNDLE_WORKING_TIME_num=$(date -d"$BUNDLE_WORKING_TIME" +%s)
        if [ $BUNDLE_WORKING_TIME_num -lt $BUNDLE_INSTALL_TIME_num ];then
            break
        fi
        if [ ! -f "$THREADDUMP_LOG_DIR/$BUNDLE_WORKING_TIME.log"];then
            BUNDLE_WORKING_TIME_num=$(expr $BUNDLE_WORKING_TIME_num - 3)
            BUNDLE_WORKING_TIME=$(date -d "$(($BUNDLE_WORKING_TIME_num - `date '+%s'` )) sec" +"%Y-%m-%d %H:%M:%S")
            continue
        else
            cat "$THREADDUMP_LOG_DIR/$BUNDLE_WORKING_TIME.log" | grep -A8 "$BUNDLE_REFRESH_THREADNAME" > $ANALYSE_OUTPUT_DIR/$BUNDLENAME.log
            CNT_ANALYSE_TIME=$(expr $CNT_ANALYSE_TIME + 1)
        fi
    done
done
