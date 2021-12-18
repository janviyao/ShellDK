#!/bin/bash
TEST_DEBUG=yes

function bool_v
{
    para=$1
    if [ "${para,,}" == "yes" -o "${para,,}" == "true" -o "${para,,}" == "y" -o "${para}" == "1" ]; then
        return 1
    else
        return 0
    fi
}

function trunc_name
{
    name_str=`echo "$1" | sed "s#${WORK_DIR}/##g"`
    echo "${name_str}"
}

function get_scsi_dev
{
    target_ip=$1
    
    start_line=1
    scsi_dev_list=""
    iscsi_str=`iscsiadm -m session -P 3`
    
    tar_lines=`echo "${iscsi_str}" | grep -n "Target:" | awk -F: '{ print $1 }'`
    for tar_line in ${tar_lines}
    do
        if [ ${start_line} -lt ${tar_line} ];then
            
            is_match=`echo "${iscsi_str}" | sed -n "${start_line},${tar_line}p" | grep "${target_ip}"`
            if [ ! -z "${is_match}" ];then
                dev_name=`echo "${iscsi_str}" | sed -n "${start_line},${tar_line}p" | grep "scsi disk" | grep "running" | awk -v ORS=" " '{ print $4 }'`
                #echo_debug "line ${start_line}-${tar_line}=${dev_name}"
                if [ ! -z "${dev_name}" ];then
                    scsi_dev_list="${scsi_dev_list} ${dev_name}"
                fi
            fi
        fi
        
        start_line=${tar_line}
    done
    
    is_match=`echo "${iscsi_str}" | sed -n "${start_line},\\$p" | grep "${target_ip}"`
    if [ ! -z "${is_match}" ];then
        dev_name=`echo "${iscsi_str}" | sed -n "${start_line},\\$p" | grep "scsi disk" | grep "running" | awk -v ORS=" " '{ print $4 }'`
        #echo_debug "line ${start_line}-$=${dev_name}"
        if [ ! -z "${dev_name}" ];then
            scsi_dev_list="${scsi_dev_list} ${dev_name}"
        fi
    fi
    
    echo "@return@${scsi_dev_list}"
}

function cov2devname
{
    dev_num=$1

    name_type=2 
    dev_cnt=0
    name_list=""
    while [ ${dev_cnt} -lt ${dev_num} ]
    do
        if [ ${name_type} -eq 2 ]; then
            dev_pre="sd"
        elif [ ${name_type} -eq 3 ];then
            dev_pre="sda"
        elif [ ${name_type} -eq 4 ];then
            dev_pre="sdb"
        else
            echo_erro "device number too big"
            exit -1
        fi
        
        IS_STOP=0
        for pdev in {a..z}
        do
            if [ ${dev_cnt} -eq ${dev_num} ];then
                break
            fi
            
            if [ x"${dev_pre}${pdev}" == x"sda" ];then
                continue
            fi

            if [ -z "${name_list}" ];then
                name_list="${dev_pre}${pdev}"  
            else
                name_list="${name_list} ${dev_pre}${pdev}"  
            fi
            let dev_cnt++
        done

        if [ ${IS_STOP} -eq 1 ];then
            break
        fi

        let name_type++
    done
    echo "${name_list}"
}

COLOR_ERROR='\033[41;30m' #红底黑字
COLOR_DEBUG='\033[43;30m' #黄底黑字
COLOR_INFO='\033[42;37m'  #绿底白字
COLOR_WARN='\033[42;31m'  #蓝底红字
COLOR_CLOSE='\033[0m'     #关闭颜色
FONT_BOLD='\033[1m'       #字体变粗
FONT_BLINK='\033[5m'      #字体闪烁

function echo_header
{
    cur_time=`date '+%Y-%m-%d %H:%M:%S'` 
    echo "${COLOR_INFO}******@${FONT_BOLD}${cur_time}: ${COLOR_CLOSE}"
}

function echo_erro()
{
    para=$1
    echo -e "$(echo_header)${COLOR_ERROR}${FONT_BLINK}${para}${COLOR_CLOSE}"
}

function echo_info()
{
    para=$1
    echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE}"
}

function echo_warn()
{
    para=$1
    echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE}"
}

function echo_debug()
{
    para=$1
    iftrue=$(bool_v "${TEST_DEBUG}"; echo $?)
    if [ ${iftrue} -eq 1 ]; then
        echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE}"
    fi
}

