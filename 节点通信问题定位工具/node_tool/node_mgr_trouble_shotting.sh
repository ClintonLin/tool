#!/bin/bash
#######################################################
# 说明:
# 1.必须以root用户执行，因为需要执行crm命令
# 2.支持I2000单机、双机场景的检测
# 3.不支持安装在windows、redhat、aix上的bmu的检测，目前仅支持suse
# 4.不支持安装在I2000服务器上的bmu的检测
# 5.不支持多dmu场景
#######################################################

BASE_PATH=$(readlink -m $0)
BASE_DIR=$(dirname $BASE_PATH)
BASE_NAME=$(basename $BASE_PATH .sh)

[ -f /etc/profile.d/cie.sh ] && source /etc/profile.d/cie.sh

export PS4='+[$(debug_info=$(printf "T: %s, L:%3s, S: %s, F: %s" "$(date +%H%M%S)" "$LINENO" "$(basename "${BASH_SOURCE[0]}")" "$(for ((i=${#FUNCNAME[*]}-1; i>=0; i--)) do func_stack="$func_stack ${FUNCNAME[i]}"; done; echo $func_stack)") && echo ${debug_info:0:94})]: '

DMU_WRAPPER=$DMU_HOME/bin/wrapper.sh
[ -f $CIE_HOME/sudoScripts/dmu/bin/wrapper.sh ] && DMU_WRAPPER=$CIE_HOME/sudoScripts/dmu/bin/wrapper.sh

MQ_WRAPPER=$MQ_HOME/bin/MQ
[ -f $CIE_HOME/sudoScripts/mq/bin/MQ ] && MQ_WRAPPER=$CIE_HOME/sudoScripts/mq/bin/MQ

# Check whether the IP is legal
function check_ip()
{
    ip=$1
    echo $ip | grep -q -E "^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])$"
}

# NOT OK Result
function echo_red
{
    echo -e "\033[31;49;1m$*\033[39;49;0m"
    echo
    echo
}

# OK Result
function echo_green
{
    echo -e "\033[32;49;1m$*\033[39;49;0m"
    echo
    echo
}

function autossh()
{
    local command=$1

    if [ "$login_mode" == "password_mode" ]; then
        expect $BASE_DIR/autossh.exp password_mode $bmu_username $bmu_password $bmu_ip "$command"
    else
        if [ -z "$key_password" ]; then
            expect $BASE_DIR/autossh.exp key_mode $bmu_username $key_path               $bmu_ip "$command"
        else
            expect $BASE_DIR/autossh.exp key_mode $bmu_username $key_path $key_password $bmu_ip "$command"
        fi
    fi
}

# 1. OMU communicate MQ check
function check_omu_communicate_mq()
{
    # Check MQ status
    echo "============================================================================================"
    echo "Check MQ status"
    echo "============================================================================================"
    echo "[Info  ]: Execute the cmd [ $MQ_WRAPPER status ]."
    $MQ_WRAPPER status
    if [ $? -eq 0 ]; then
        echo_green "[Result]: MQ is running."
    else
        echo_red "[Result]: MQ is not running. Please use the cmd [ $MQ_WRAPPER start ] to start MQ."
        exit 1
    fi

    # Check MQ listener
    echo "============================================================================================"
    echo "Check MQ listener"
    echo "============================================================================================"
    echo "[Info  ]: Execute the cmd [ lsof -ni:61616 | grep LISTEN ]."
    lsof -ni:61616 | grep LISTEN
    if [ $? -eq 0 ]; then
        echo_green "[Result]: MQ listener is open."
    else
        echo_red "[Result]: MQ listener is not open. Please use the cmd [ $MQ_WRAPPER restart ] to restart MQ."
        exit 1
    fi

    # Check OMU status
    echo "============================================================================================"
    echo "Check OMU status"
    echo "============================================================================================"
    echo '[Info  ]: Execute the cmd [ $OMU_HOME/run/bin/deamon.sh status ].'
    $OMU_HOME/run/bin/deamon.sh status
    if [ $? -eq 0 ]; then
        echo_green "[Result]: OMU is running."
    else
        echo_red '[Result]: OMU is not running. Please use the cmd [ su - i2kuser -c "$OMU_HOME/bin/startup.sh" ] to start OMU.'
        exit 1
    fi

    # Check omu.properties
    echo "============================================================================================"
    echo "Check omu.properties"
    echo "============================================================================================"
    omu_mq_ip=$(cat $OMU_HOME/run/etc/omu/omu.properties | grep "mq.server.broker.url" | grep -v "#" | grep -o -E "((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])")
    echo "[Info  ]: The MQ server IP in OMU is [ $omu_mq_ip ]. File:[ \$OMU_HOME/run/etc/omu/omu.properties ], Key:[ mq.server.broker.url ]."
    echo "[Info  ]: Execute the cmd [ lsof -ni:61616 | grep LISTEN | grep -w '$omu_mq_ip' ]"
    lsof -ni:61616 | grep LISTEN | grep -w $omu_mq_ip
    if [ $? -eq 0 ]; then
        echo_green "[Result]: The MQ server IP [ $omu_mq_ip ] in OMU is correct."
    else
        mq_listen_ips=$(lsof -ni:61616 | grep LISTEN | grep -o -E "((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])" | sed "N;s/\n/ /g")
        echo_red "[Result]: The MQ server IP [ $omu_mq_ip ] in OMU is wrong. It must be one of MQ listener IPs [ $mq_listen_ips ]. Please check omu.properties."
        exit 1
    fi

    # Check OMU certificate
    echo "============================================================================================"
    echo "Check OMU certificate"
    echo "============================================================================================"
    mq_huaweiServer_md5=$(md5sum $MQ_HOME/conf/huaweiServer.ks | awk '{print $1}')
    mq_trust_md5=$(md5sum $MQ_HOME/conf/trust.store | awk '{print $1}')
    omu_huaweiServer_md5=$(md5sum $OMU_HOME/run/etc/omu/huaweiServer.ks | awk '{print $1}')
    omu_trust_md5=$(md5sum $OMU_HOME/run/etc/omu/trust.store | awk '{print $1}')
    echo "[Info  ]: \$MQ_HOME/conf/huaweiServer.ks         $mq_huaweiServer_md5"
    echo "[Info  ]: \$OMU_HOME/run/etc/omu/huaweiServer.ks $omu_huaweiServer_md5"
    echo "[Info  ]: \$MQ_HOME/conf/trust.store             $mq_trust_md5"
    echo "[Info  ]: \$OMU_HOME/run/etc/omu/trust.store     $omu_trust_md5"
    if [ "$mq_huaweiServer_md5" != "$omu_huaweiServer_md5" ]; then
        echo_red '[Result]: The OMU Certificate is not the same with MQ. [ $MQ_HOME/conf/huaweiServer.ks ] and [ $OMU_HOME/run/etc/omu/huaweiServer.ks ] is not the same.'
        exit 1
    elif [ "$mq_trust_md5" != "$omu_trust_md5" ]; then
        echo_red '[Result]: The OMU Certificate is not the same with MQ. [ $MQ_HOME/conf/trust.store ] and [ $OMU_HOME/run/etc/omu/trust.store ] is not the same.'
        exit 1
    else
        echo_green "[Result]: The OMU Certificate is the same with MQ."
    fi

    # Check OMU connection
    echo "============================================================================================"
    echo "Check OMU connection"
    echo "============================================================================================"
    for omu_pid in $(ps -efww | grep Dprocname=I2000 | grep -v grep | awk '{print $2}')
    do
        omu_pids="$omu_pids|$omu_pid"
    done
    omu_pids=${omu_pids#*|}
    echo "[Info  ]: The OMU pids are [ $omu_pids ]."
    echo "[Info  ]: Execute the cmd [ lsof -ni:61616 | grep -w $omu_mq_ip | grep -w -E '$omu_pids' ]."
    lsof -ni:61616 | grep -w $omu_mq_ip | grep -w -E $omu_pids
    if [ $? -eq 0 ]; then
        echo_green "[Result]: The OMU connection exists."
    else
        echo_red "[Result]: The OMU connection does not exist. Maybe OMU is not fully started."
        exit 1
    fi

    # Check OMU connection status
    echo "============================================================================================"
    echo "Check OMU connection status"
    echo "============================================================================================"
    echo "[Info  ]: Execute the cmd [ lsof -ni:61616 | grep -w $omu_mq_ip | grep -w -E '$omu_pids' | grep ESTABLISHED ]."
    lsof -ni:61616 | grep -w $omu_mq_ip | grep -w -E $omu_pids | grep ESTABLISHED
    if [ $? -eq 0 ]; then
        echo_green "[Result]: The OMU connection status is ESTABLISHED."
    else
        echo_red "[Result]: The OMU connection status is not ESTABLISHED."
        lsof -ni:61616 | grep -w $omu_mq_ip | grep -w -E $omu_pids
        exit 1
    fi
}

# 2. OMU communicate DMU check
function check_omu_communicate_dmu()
{
    # Check DMU status
    echo "============================================================================================"
    echo "Check DMU status"
    echo "============================================================================================"
    echo "[Info  ]: Execute the cmd [ $DMU_WRAPPER status ]."
    $DMU_WRAPPER status
    if [ $? -eq 0 ]; then
        echo_green "[Result]: DMU is running."
    else
        echo_red "[Result]: DMU is not running. Please use the cmd [ $DMU_WRAPPER start ] to start DMU."
        exit 1
    fi

    # Check dmu.properties
    echo "============================================================================================"
    echo "Check dmu.properties"
    echo "============================================================================================"
    dmu_mq_ip=$(cat $DMU_HOME/config/dmu.properties | grep "mq.server.broker.url" | grep -v "#" | grep -o -E "((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])")
    echo "[Info  ]: The MQ server IP in DMU is [ $dmu_mq_ip ]. File:[ \$DMU_HOME/config/dmu.properties ], Key:[ mq.server.broker.url ]."
    echo "[Info  ]: Execute the cmd [ lsof -ni:61616 | grep LISTEN | grep -w '$dmu_mq_ip' ]"
    lsof -ni:61616 | grep LISTEN | grep -w $dmu_mq_ip
    if [ $? -eq 0 ]; then
        echo_green "[Result]: The MQ server IP [ $dmu_mq_ip ] in DMU is correct."
    else
        mq_listen_ips=$(lsof -ni:61616 | grep LISTEN | grep -o -E "((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])" | sed "N;s/\n/ /g")
        echo_red "[Result]: The MQ server IP [ $dmu_mq_ip ] in DMU is wrong. It must be one of MQ listener IPs [ $mq_listen_ips ]. Please check dmu.properties."
        exit 1
    fi

    # Check DMU certificate
    echo "============================================================================================"
    echo "Check DMU certificate"
    echo "============================================================================================"
    mq_huaweiServer_md5=$(md5sum $MQ_HOME/conf/huaweiServer.ks | awk '{print $1}')
    mq_trust_md5=$(md5sum $MQ_HOME/conf/trust.store | awk '{print $1}')
    dmu_huaweiServer_md5=$(md5sum $DMU_HOME/config/huaweiServer.ks | awk '{print $1}')
    dmu_trust_md5=$(md5sum $DMU_HOME/config/trust.store | awk '{print $1}')
    echo "[Info  ]: \$MQ_HOME/conf/huaweiServer.ks    $mq_huaweiServer_md5"
    echo "[Info  ]: \$DMU_HOME/config/huaweiServer.ks $dmu_huaweiServer_md5"
    echo "[Info  ]: \$MQ_HOME/conf/trust.store        $mq_trust_md5"
    echo "[Info  ]: \$DMU_HOME/config/trust.store     $dmu_trust_md5"
    if [ "$mq_huaweiServer_md5" != "$dmu_huaweiServer_md5" ]; then
        echo_red '[Result]: The DMU Certificate is not the same with MQ. [ $MQ_HOME/conf/huaweiServer.ks ] and [ $DMU_HOME/config/huaweiServer.ks ] is not the same.'
        exit 1
    elif [ "$mq_trust_md5" != "$dmu_trust_md5" ]; then
        echo_red '[Result]: The DMU Certificate is not the same with MQ. [ $MQ_HOME/conf/trust.store ] and [ $DMU_HOME/config/trust.store ] is not the same.'
        exit 1
    else
        echo_green "[Result]: The DMU Certificate is the same with MQ."
    fi

    # Check DMU connection
    echo "============================================================================================"
    echo "Check DMU connection"
    echo "============================================================================================"
    dmu_pid=$(ps -efww | grep $DMU_HOME/jre/bin/java | grep system.name=DMU | grep -v grep | awk '{print $2}')
    echo "[Info  ]: The DMU pid is [ $dmu_pid ]."
    echo "[Info  ]: Execute the cmd [ lsof -ni:61616 | grep -w $dmu_mq_ip | grep -w '$dmu_pid' ]."
    lsof -ni:61616 | grep -w $dmu_mq_ip | grep -w $dmu_pid
    if [ $? -eq 0 ]; then
        echo_green "[Result]: The DMU connection exists."
    else
        echo_red "[Result]: The DMU connection does not exist. Maybe DMU is not fully started."
        exit 1
    fi

    # Check DMU connection status
    echo "============================================================================================"
    echo "Check DMU connection status"
    echo "============================================================================================"
    echo "[Info  ]: Execute the cmd [ lsof -ni:61616 | grep -w $dmu_mq_ip | grep -w '$dmu_pid' | grep ESTABLISHED ]."
    lsof -ni:61616 | grep -w $dmu_mq_ip | grep -w $dmu_pid | grep ESTABLISHED
    if [ $? -eq 0 ]; then
        echo_green "[Result]: The DMU connection status is ESTABLISHED."
    else
        echo_red "[Result]: The DMU connection status is not ESTABLISHED."
        lsof -ni:61616 | grep -w $dmu_mq_ip | grep -w $dmu_pid
        exit 1
    fi
}

# 3.DMU communicate BMU check
function check_dmu_communicate_bmu()
{
    # Check BMU install
    echo "============================================================================================"
    echo "Check BMU install"
    echo "============================================================================================"
    bmu_path=$(autossh '[ -n "$BMU_HOME" ] && [ -d "$BMU_HOME/repository" ] && echo "$BMU_HOME"' | sed 's/\r//g' | sed '1,/^====autossh.exp====$/d')
    echo "[Info  ]: The BMU install path is [ $bmu_path ]."
    if [ -n "$bmu_path" ]; then
        echo_green "[Result]: BMU is installed."
    else
        echo_red "[Result]: BMU is not installed."
        exit 1
    fi

    # Check BMU version
    echo "============================================================================================"
    echo "Check BMU version"
    echo "============================================================================================"
    bmu_version=$(autossh 'cat $BMU_HOME/version.txt' | sed 's/\r//g' | sed '1,/^====autossh.exp====$/d' | grep VERSION | awk -F= '{print $2}' | sed 's/\s*//g')
    dmu_version=$(cat $DMU_HOME/version.txt | head -1 | awk -F= '{print $2}' | sed 's/\s*//g')
    echo "[Info  ]: BMU version is [ $bmu_version ]."
    echo "[Info  ]: DMU version is [ $dmu_version ]."
    if [ "$bmu_version" = "$dmu_version" ]; then
        echo_green "[Result]: BMU version is the same with DMU."
    else
        echo_red "[Result]: BMU version is not the same with DMU."
    fi

    # Check BMU jre
    echo "============================================================================================"
    echo "Check BMU jre"
    echo "============================================================================================"
    echo '[Info  ]: Execute the cmd [ $BMU_HOME/jre/bin/java -version ] in BMU.'
    bmu_jre=$(autossh '[ -x $BMU_HOME/jre/bin/java ] && $BMU_HOME/jre/bin/java -version' | sed 's/\r//g' | sed '1,/^====autossh.exp====$/d' | grep "java version")
    echo "[Info  ]: The BMU jre version is [ $bmu_jre ]."
    if [ -n "$bmu_jre" ]; then
        echo_green "[Result]: BMU jre is installed correctly."
    else
        echo_red "[Result]: BMU jre is not installed correctly."
        exit 1
    fi

    # Check BMU status
    echo "============================================================================================"
    echo "Check BMU status"
    echo "============================================================================================"
    echo '[Info  ]: Execute the cmd [ $BMU_HOME/bin/wrapper.sh status ] in BMU.'
    bmu_status=$(autossh '$BMU_HOME/bin/wrapper.sh status' | sed 's/\r//g' | sed '1,/^====autossh.exp====$/d')
    echo "[Info  ]: BMU status is [ $bmu_status ]."
    if [ "$bmu_status" = "BMU is running." ]; then
        echo_green "[Result]: BMU is running."
    else
        echo_red '[Result]: BMU is not running. Please use the cmd [ $BMU_HOME/bin/wrapper.sh start ] to start BMU.'
        exit 1
    fi

    # Check MQ listener for BMU
    echo "============================================================================================"
    echo "Check MQ listener for BMU"
    echo "============================================================================================"
    which crm >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        float_ip=$(lsof -ni:61616 | grep LISTEN | grep -v 127.0.0.1 | grep -o -E "((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])")
        echo "[Info  ]: I2000 type is dual host. The float ip is [ $float_ip ]."
        bmu_mq_ip=$float_ip
        echo "[Info  ]: In dual host scene, the MQ server IP must be the same with the float ip [ $float_ip ]."

        echo "[Info  ]: Execute the cmd [ ping $bmu_ip -I $bmu_mq_ip -c 2 ]."
        ping $bmu_ip -I $bmu_mq_ip -c 2
        if [ $? -eq 0 ]; then
            echo "[Info  ]: Host [ $bmu_ip ] could be reached from [ $bmu_mq_ip ]. The network status is ok."
        else
            echo_red "[Result]: Host [ $bmu_ip ] could not be reached from [ $bmu_mq_ip ]. Please check the network status."
            exit 1
        fi
    else
        # In single host scene, get the MQ server IP by network route.
        echo "[Info  ]: Get the MQ server IP for BMU. Execute the cmd [ ip route ge $bmu_ip | grep src | awk -F 'src ' '{print \$2}' | sed 's/\s*//g' ]."
        bmu_mq_ip=$(ip route ge $bmu_ip | grep src | awk -F 'src ' '{print $2}' | sed 's/\s*//g')
    fi
    echo "[Info  ]: The MQ server IP for BMU is [ $bmu_mq_ip ]. In other words, BMU [ $bmu_ip ] connects to MQ [ $bmu_mq_ip ] with the given IPs."
    echo "[Info  ]: Execute the cmd [ lsof -ni:61616 | grep LISTEN | grep -w '$bmu_mq_ip' ]."
    lsof -ni:61616 | grep LISTEN | grep -w $bmu_mq_ip
    if [ $? -eq 0 ]; then
        echo_green "[Result]: The MQ server IP [ $bmu_mq_ip ] for BMU [ $bmu_ip ] is open."
    else
        mq_listen_ips=$(lsof -ni:61616 | grep LISTEN | grep -o -E "((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])" | sed "N;s/\n/ /g")
        echo_red "[Result]: The MQ server IP [ $bmu_mq_ip ] for BMU [ $bmu_ip ] is not open. The MQ listener IPs are [ $mq_listen_ips ]. The BMU IP [ $bmu_ip ] may be not right or the MQ server is not configed properly. The MQ server config file is [ \$MQ_HOME/conf/mq.cfg ]."
        exit 1
    fi

    # Check bmu.properties
    echo "============================================================================================"
    echo "Check bmu.properties"
    echo "============================================================================================"
    echo '[Info  ]: Check whether the MQ server IP in BMU is correct. File:[ $BMU_HOME/config/bmu.properties ], Key:[ mq.server.broker.url ].'
    autossh 'cat $BMU_HOME/config/bmu.properties | grep mq.server.broker.url | grep -v "#"' | sed 's/\r//g' | sed '1,/^====autossh.exp====$/d' | grep -q -w "$bmu_mq_ip"
    if [ $? -eq 0 ]; then
        echo_green "[Result]: The MQ server IP in bmu.properties is correct."
    else
        echo_red "[Result]: The MQ server IP in bmu.properties is wrong. The MQ server IP [ $bmu_mq_ip ] is not configed in bmu.properties."
        exit 1
    fi

    # Check BMU certificate
    echo "============================================================================================"
    echo "Check BMU certificate"
    echo "============================================================================================"
    mq_trust_md5=$(md5sum $MQ_HOME/conf/trust.store | awk '{print $1}')
    bmu_trust_md5=$(autossh 'md5sum $BMU_HOME/config/trust.store' | sed 's/\r//g' | sed '1,/^====autossh.exp====$/d' | awk '{print $1}')
    echo "[Info  ]: \$MQ_HOME/conf/trust.store    $mq_trust_md5"
    echo "[Info  ]: \$BMU_HOME/config/trust.store $bmu_trust_md5"
    if [ "$mq_trust_md5" != "$bmu_trust_md5" ]; then
        echo_red '[Result]: The BMU Certificate is not the same with MQ. [ $MQ_HOME/conf/trust.store ] and [ $BMU_HOME/config/trust.store ] is not the same.'
        exit 1
    else
        echo_green "[Result]: The BMU Certificate is the same with MQ."
    fi

    # Check BMU connection
    echo "============================================================================================"
    echo "Check BMU connection"
    echo "============================================================================================"
    bmu_pid=$(autossh 'ps -efww | grep $BMU_HOME/jre/bin/java | grep system.name=BMU | grep -v grep' | sed 's/\r//g' | sed '1,/^====autossh.exp====$/d' | awk '{print $2}')
    echo "[Info  ]: The BMU pid is [ $bmu_pid ]."
    echo "[Info  ]: Execute the cmd [ lsof -ni:61616 | grep -w $bmu_mq_ip | grep -w $bmu_pid ] in BMU."
    autossh 'lsof -ni:61616' | sed 's/\r//g' | sed '1,/^====autossh.exp====$/d' | grep -w $bmu_mq_ip | grep -w $bmu_pid
    if [ $? -eq 0 ]; then
        echo_green "[Result]: The BMU connection exists."
    else
        echo "[Info  ]: Execute the cmd [ lsof -ni:61616 | grep -w $bmu_pid ] in BMU."
        autossh 'lsof -ni:61616' | sed 's/\r//g' | sed '1,/^====autossh.exp====$/d' | grep -w $bmu_pid
        if [ $? -eq 0 ]; then
            echo_red "[Result]: The BMU connection does not exist. BMU already connects to other MQ server."
        else
            echo_red "[Result]: The BMU connection does not exist. Maybe BMU is not fully started."
        fi
        exit 1
    fi

    # Check BMU connection status
    echo "============================================================================================"
    echo "Check BMU connection status"
    echo "============================================================================================"
    echo "[Info  ]: Execute the cmd [ lsof -ni:61616 | grep -w $bmu_mq_ip | grep -w $bmu_pid | grep ESTABLISHED ] in BMU."
    autossh 'lsof -ni:61616' | sed 's/\r//g' | sed '1,/^====autossh.exp====$/d' | grep -w $bmu_mq_ip | grep -w $bmu_pid | grep ESTABLISHED
    if [ $? -eq 0 ]; then
        echo_green "[Result]: The BMU connection status is ESTABLISHED."
    else
        echo_red "[Result]: The BMU connection status is not ESTABLISHED."
        autossh 'lsof -ni:61616' | sed 's/\r//g' | sed '1,/^====autossh.exp====$/d' | grep -w $bmu_mq_ip | grep -w $bmu_pid
        exit 1
    fi
}

# 4.Data in Table situation
function check_data_in_database()
{
    bmu_macs_file=/tmp/node_tool_bmu_macs.txt
    cie_support_nodeinfo_sql_file=/tmp/node_tool_cie_support_nodeinfo.sql
    cie_support_nodeinfo_txt_file=/tmp/node_tool_cie_support_nodeinfo.txt
    tbl_resource_sql_file=/tmp/node_tool_tbl_resource.sql
    tbl_resource_txt_file=/tmp/node_tool_tbl_resource.txt
    t_dmu_instance_nic_sql_file=/tmp/node_tool_t_dmu_instance_nic.sql
    t_dmu_instance_nic_txt_file=/tmp/node_tool_t_dmu_instance_nic.txt

    >$bmu_macs_file
    >$cie_support_nodeinfo_sql_file
    >$cie_support_nodeinfo_txt_file
    >$tbl_resource_sql_file
    >$tbl_resource_txt_file
    >$t_dmu_instance_nic_sql_file
    >$t_dmu_instance_nic_txt_file

    chmod 777 /tmp/node_tool_*

    PT_USER=i2kuser
    id ptuser >/dev/null 2>&1 && PT_USER=ptuser

    # Get BMU macs
    echo "============================================================================================"
    echo "Get BMU macs"
    echo "============================================================================================"
    echo "[Info  ]: BMU macs are:"
    autossh 'cat /sys/class/net/eth*/address' | sed 's/\r//g' | sed '1,/^====autossh.exp====$/d' >$bmu_macs_file
    cat $bmu_macs_file
    echo "[Info  ]: BMU macs are: ( [:] --> [-] )"
    cat $bmu_macs_file | sed 's/:/-/g'

    # Get device info from table dmuuser.tbl_resource
    echo "============================================================================================"
    echo "Get device info from table dmuuser.tbl_resource"
    echo "============================================================================================"
    while read bmu_mac
    do
        bmu_mac=$(echo $bmu_mac | sed 's/:/-/g')
        macaddress_para="$macaddress_para macaddress like '%$bmu_mac%' or"
    done <$bmu_macs_file
    macaddress_para=${macaddress_para%or*}
    echo "SELECT dn,ipaddress,macaddress,name FROM dmuuser.tbl_resource where $macaddress_para or ipaddress like '$bmu_ip' or ipaddress like '%,$bmu_ip' or ipaddress like '$bmu_ip,%' or ipaddress like '%,$bmu_ip,%';" >$tbl_resource_sql_file
    echo "[Info  ]: Query table dmuuser.tbl_resource sql:"
    cat $tbl_resource_sql_file
    echo "[Info  ]: Query table dmuuser.tbl_resource result:"
    su - $PT_USER -c "psql -d dmudb -U dmuuser -p 1525 <$tbl_resource_sql_file" | tee $tbl_resource_txt_file

    # Get instance nic info from table dmuuser.t_dmu_instance_nic
    echo "============================================================================================"
    echo "Get instance nic info from table dmuuser.t_dmu_instance_nic"
    echo "============================================================================================"
    while read bmu_mac
    do
        mac_para="$mac_para mac like '%$bmu_mac%' or"
    done <$bmu_macs_file
    mac_para=${mac_para%or*}
    echo "SELECT instanceid,ip,mac FROM dmuuser.t_dmu_instance_nic where $mac_para or ip like '$bmu_ip' or ip like '%,$bmu_ip' or ip like '$bmu_ip,%' or ip like '%,$bmu_ip,%';" >$t_dmu_instance_nic_sql_file
    echo "[Info  ]: Query table dmuuser.t_dmu_instance_nic sql:"
    cat $t_dmu_instance_nic_sql_file
    echo "[Info  ]: Query table dmuuser.t_dmu_instance_nic result:"
    su - $PT_USER -c "psql -d dmudb -U dmuuser -p 1525 <$t_dmu_instance_nic_sql_file" | tee $t_dmu_instance_nic_txt_file

    # Check table dmuuser.cie_support_nodeinfo
    echo "============================================================================================"
    echo "Check table dmuuser.cie_support_nodeinfo"
    echo "============================================================================================"
    while read bmu_mac
    do
        bmu_mac=$(echo $bmu_mac | sed 's/:/-/g')
        physicalid_para="$physicalid_para physicalid like '%$bmu_mac%' or"
    done <$bmu_macs_file
    physicalid_para=${physicalid_para%or*}
    echo "SELECT name,deviceid,listenmac,physicalid,type FROM dmuuser.cie_support_nodeinfo where ($physicalid_para) and type='BMU';" >$cie_support_nodeinfo_sql_file
    echo "[Info  ]: Query table dmuuser.cie_support_nodeinfo sql:"
    cat $cie_support_nodeinfo_sql_file
    echo "[Info  ]: Query table dmuuser.cie_support_nodeinfo result:"
    su - $PT_USER -c "psql -d dmudb -U dmuuser -p 1525 <$cie_support_nodeinfo_sql_file" | tee $cie_support_nodeinfo_txt_file
    node_count=$(cat $cie_support_nodeinfo_txt_file | grep 'row' | awk '{print $1}' | sed 's/(//g')

    [ -f "$bmu_macs_file" ]                 && rm $bmu_macs_file
    [ -f "$cie_support_nodeinfo_sql_file" ] && rm $cie_support_nodeinfo_sql_file
    [ -f "$cie_support_nodeinfo_txt_file" ] && rm $cie_support_nodeinfo_txt_file
    [ -f "$tbl_resource_sql_file" ]         && rm $tbl_resource_sql_file
    [ -f "$tbl_resource_txt_file" ]         && rm $tbl_resource_txt_file
    [ -f "$t_dmu_instance_nic_sql_file" ]   && rm $t_dmu_instance_nic_sql_file
    [ -f "$t_dmu_instance_nic_txt_file" ]   && rm $t_dmu_instance_nic_txt_file

    if [ "$node_count" = "1" ]; then
        echo_green "[Result]: Find $node_count item for BMU in table dmuuser.cie_support_nodeinfo. It is correct."
    elif [ "$node_count" = "0" ]; then
        echo_red "[Result]: Find no item for BMU in table dmuuser.cie_support_nodeinfo. It is not correct."
        exit 1
    else
        echo_red "[Result]: Find too many [ $node_count ] items for BMU in table dmuuser.cie_support_nodeinfo. Mac address duplication. It is not correct."
        exit 1
    fi
}

if [ $(whoami) != "root" ]; then
    echo "You must run with [ root ] user."
    exit 1
fi

echo "Two kinds of usage are as follows:"
echo "  sh $0           check communication among MQ, OMU, DMU."
echo "  sh $0 <bmu_ip>  check communication among MQ, OMU, DMU, BMU."
echo ""

if [ $# -eq 0 ]; then
    echo "BMU IP is not specified, just check communication between OMU and DMU."
    echo
elif [ $# -eq 1 ]; then
    bmu_ip=$1
    check_ip $bmu_ip
    [ $? -ne 0 ] && echo "bmu_ip [$bmu_ip] is not valid." && exit 1

    read -p "Please enter login mode(password_mode or key_mode, leave blank for password_mode): " login_mode
    [ -z "$login_mode" ] && login_mode=password_mode
    [ "$login_mode" != "password_mode" -a "$login_mode" != "key_mode" ] && echo "Login mode must be [ password_mode ] or [ key_mode ]." && exit 1

    read -p "Please enter bmu username(root or bmuuser): " bmu_username
    [ "$bmu_username" != "root" -a "$bmu_username" != "bmuuser" ] && echo "Username must be [ root ] or [ bmuuser ]." && exit 1

    if [ "$login_mode" == "password_mode" ]; then
        read -s -r -p "Please enter bmu password: " bmu_password
        [ -z "$bmu_password" ] && echo "Bmu password could not be empty." && exit 1
        echo
        echo
    else
        read -p "Please enter key path, leave blank for ~/.ssh/id_rsa: " key_path
        [ -z "$key_path" ] && key_path="~/.ssh/id_rsa"
        # 输入的路径中可能包含变量，使用eval进行二次解析。##
        key_path=$(eval echo $key_path)
        [ ! -f "$key_path" ] && echo "Key file [ $key_path ] does not exist." && exit 1

        read -s -r -p "Please enter key password, leave blank if the key file is no password: " key_password
        echo
        echo
    fi

    autossh "pwd" >/dev/null
    [ $? -ne 0 ] && echo "Connect to bmu failed." && exit 1
else
    echo "Args error. Please refer to usage."
    exit 1
fi

check_omu_communicate_mq
check_omu_communicate_dmu
if [ -n "$bmu_ip" ]; then
    check_dmu_communicate_bmu
    check_data_in_database
fi

exit 0
