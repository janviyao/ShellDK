#!/bin/sh
source ${TEST_SUIT_ENV}

echo_debug "@@@@@@: $(echo `basename $0`) @${APP_WORK_DIR} @${LOCAL_IP}"

if ! bool_v "${KEEP_ENV_STATE}";then
    echo_info "init devs: ${LOCAL_IP}"
else
    echo_info "keep devs: ${LOCAL_IP}"
    exit 0
fi

echo_info "discover: { ${LOCAL_IP} } --> { ${ISCSI_TARGET_IP_ARRAY} }"

function get_scsi_dev
{
    local target_ip=$1
    local start_line=1
    local scsi_dev_list=""
    local iscsi_str=`iscsiadm -m session -P 3`
    
    local tar_lines=`echo "${iscsi_str}" | grep -n "Target:" | awk -F: '{ print $1 }'`
    for tar_line in ${tar_lines}
    do
        if [ ${start_line} -lt ${tar_line} ];then
            local is_match=`echo "${iscsi_str}" | sed -n "${start_line},${tar_line}p" | grep "${target_ip}"`
            if [ ! -z "${is_match}" ];then
                local dev_name=`echo "${iscsi_str}" | sed -n "${start_line},${tar_line}p" | grep "scsi disk" | grep "running" | awk -v ORS=" " '{ print $4 }'`
                #echo_debug "line ${start_line}-${tar_line}=${dev_name}"
                if [ ! -z "${dev_name}" ];then
                    scsi_dev_list="${scsi_dev_list} ${dev_name}"
                fi
            fi
        fi
        
        start_line=${tar_line}
    done
    
    local is_match=`echo "${iscsi_str}" | sed -n "${start_line},\\$p" | grep "${target_ip}"`
    if [ ! -z "${is_match}" ];then
        local dev_name=`echo "${iscsi_str}" | sed -n "${start_line},\\$p" | grep "scsi disk" | grep "running" | awk -v ORS=" " '{ print $4 }'`
        #echo_debug "line ${start_line}-$=${dev_name}"
        if [ ! -z "${dev_name}" ];then
            scsi_dev_list="${scsi_dev_list} ${dev_name}"
        fi
    fi
    
    echo "@return@${scsi_dev_list}"
}

ifloaded=`lsmod | grep dm_multipath | wc -l`
if ! bool_v "${ISCSI_MULTIPATH_ON}";then
    echo_info "stop: multipathd"
    if [ ${ifloaded} -gt 0 ];then
        systemctl stop multipathd
    fi
else
    is_installed=`rpm -qa | grep device-mapper | wc -l`
    if [ ${is_installed} -eq 0 ];then
        echo_warn "install device-mapper"
        yum install -y device-mapper
    fi

    is_installed=`rpm -qa | grep device-mapper-multipath | wc -l`
    if [ ${is_installed} -eq 0 ];then
        echo_warn "install device-mapper-multipath"
        yum install -y device-mapper-multipath
    fi

    if [ ${ifloaded} -eq 0 ];then
        echo_info "modprobe multipath"
        modprobe dm-multipath
        modprobe dm-round-robin

        ifloaded=`lsmod | grep dm_multipath | wc -l`
        if [ ${ifloaded} -eq 0 ];then
            echo_erro "multipath ko not loaded" 
            exit -1
        fi
    fi

    ifstart=`ps -ef | grep multipathd | grep -v grep | wc -l`
    if [ ${ifstart} -ne 1 ];then
        echo_info "start: multipathd"
        systemctl start multipathd
    fi
fi

is_installed=`rpm -qa | grep iscsi-initiator-utils | wc -l`
if [ ${is_installed} -eq 0 ];then
    echo_warn "install iscsi-initiator-utils"
    yum install -y iscsi-initiator-utils
fi

if bool_v "${RESTART_ISCSI_INITIATOR}";then
    echo_info "restart: iscsid"
    mkdir -p /etc/iscsi
    [ -f iscsid.conf ] && mv iscsid.conf /etc/iscsi/
    systemctl stop iscsid
    systemctl stop iscsid.socket
    systemctl start iscsid

    #sh stop_p.sh kill "iscsid"
    #rm -f iscsid.log
    #iscsid -d 8 -c /etc/iscsi/iscsid.conf -i /etc/iscsi/initiatorname.iscsi -f &> iscsid.log &
else
    echo_info "keep: iscsid"
    [ -f iscsid.conf ] && rm -f iscsid.conf
fi

IS_ON=$(bool_v "${ISCSI_MULTIPATH_ON}";echo $?)
IS_RST=$(bool_v "${RSRESTART_ISCSI_MUTLIPATHT_MTP}";echo $?)
if [ ${IS_RST} -eq 1 -a ${IS_ON} -eq 1 ];then
    echo_info "restart: multipath"
    [ -f multipath.conf ] && mv multipath.conf /etc/
    systemctl restart multipathd
else
    echo_info "keep: multipath"
    [ -f multipath.conf ] && rm -f multipath.conf
fi

if bool_v "${APPLY_SYSCTRL}";then
    echo_info "restart: sysctl"
    [ -f sysctl.conf ] && mv sysctl.conf /etc/
    sh log.sh sysctl -p
else
    echo_info "keep: sysctl"
    [ -f sysctl.conf ] && rm -f sysctl.conf
fi

for t_index in $(seq 0 ${MAX_TARGET_NUM})
do
    map_value_str="${ISCSI_INFO_MAP[${LOCAL_IP}-${t_index}]}"
    if [ -z "${map_value_str}" ];then
        break
    fi

    target_ip=`echo "${map_value_str}" | cut -d " " -f 1`
    target_nm=`echo "${map_value_str}" | cut -d " " -f 2`

    sh log.sh iscsiadm -m discovery -t sendtargets -p ${target_ip}
    sleep 1

    iscsiadm -m node -o update -n node.conn[0].iscsi.HeaderDigest -v ${ISCSI_HEADER_DIGEST}
    #iscsiadm -m node -o update -n node.conn[0].iscsi.DataDigest -v ${ISCSI_DATA_DIGEST}
    iscsiadm -m node -o update -n node.session.nr_sessions -v ${ISCSI_SESSION_NR}

    sh log.sh iscsiadm -m node -T ${target_nm} -p ${target_ip} --login
done

sleep 5

get_dev_list=""
for ipaddr in ${ISCSI_TARGET_IP_ARRAY}
do
    dev_list=$(get_scsi_dev "${ipaddr}")
    show_res=`echo "${dev_list}" | grep -v "@return@"`                                                                                                                                                
    if [ ! -z "${show_res}" ];then
        echo "${show_res}"
    fi
    dev_list=`echo "${dev_list}" | grep -P "@return@" | awk -F@ '{print $3}'`
    
    echo_debug "devs: { ${dev_list} } from ${ipaddr}"
    get_dev_list="${get_dev_list} ${dev_list}"
done
get_mdev_list=""

if ! bool_v "${ISCSI_MULTIPATH_ON}";then
    for dev in ${get_dev_list}
    do
        if [ -b /dev/${dev} ];then
            sh dev_conf.sh ${dev} ${DEV_QD}
        else
            echo_erro "absence: { /dev/${dev} }"
            exit -1
        fi
    done
else
    sh log.sh multipath -r
    
    get_mdev_list="dm-0"
    for index in {1..64}
    do
        if [ -b /dev/dm-${index} ];then
            get_mdev_list="${get_mdev_list} dm-${index} "
        fi
    done
    
    for mdev in ${get_mdev_list}
    do
        if [ -b /dev/${mdev} ];then
            sh dev_conf.sh ${mdev} ${MULTIPATH_DEV_QD}
            for slave in `ls /sys/block/${mdev}/slaves`
            do
                sh dev_conf.sh ${slave} ${DEV_QD}
            done
        else
            echo_erro "absence: { /dev/${mdev} }"
        fi
    done
fi

dev_num=`echo "${get_dev_list}" | awk '{ print NF }'`
mdev_num=`echo "${get_mdev_list}" | awk '{ print NF }'`
echo_info "\nmpath: { ${ISCSI_MULTIPATH_ON} } dev(${dev_num}): {${get_dev_list}} mdev(${mdev_num}): {${get_mdev_list}}"
echo "${get_dev_list}" > ${APP_WORK_DIR}/devs.${LOCAL_IP}
echo "${get_mdev_list}" > ${APP_WORK_DIR}/mdevs.${LOCAL_IP}

echo_info "launch fio server"
nohup ./fio --server &>> log &
