#!/bin/bash
#set -e # when error, then exit
#set -u # variable not exist, then exit
HOME_DIR=${HOME}

TEST_DEBUG=0
LOG_ENABLE=".+"
LOG_HEADER=true

OP_TRY_CNT=3
OP_TIMEOUT=60

SUDO=""
if [ $UID -ne 0 ]; then
    which sudo &> /dev/null
    if [ $? -eq 0 ]; then
        which expect &> /dev/null
        if [ $? -eq 0 ]; then
            SUDO="$MY_VIM_DIR/tools/sudo.sh"
        else
            SUDO="sudo"
        fi
    fi
else
    which sudo &> /dev/null
    if [ $? -eq 0 ]; then
        SUDO="sudo"
    fi
fi

function bool_v
{
    local para=$1
    if [ "${para,,}" == "yes" -o "${para,,}" == "true" -o "${para,,}" == "y" -o "${para}" == "1" ]; then
        return 0
    else
        return 1
    fi
}

function access_ok
{
    local para="$1"

    which ${para} &> /dev/null
    if [ $? -eq 0 ];then
        return 0
    fi

    if [ -d ${para} ];then
        return 0
    elif [ -f ${para} ];then
        return 0
    elif [ -b ${para} ];then
        return 0
    elif [ -c ${para} ];then
        return 0
    elif [ -h ${para} ];then
        return 0
    elif [ -r ${para} -o -w ${para} -o -x ${para} ];then
        return 0
    fi
     
    return 1
}

function file_name
{
    local full_name="$0"
    if [[ ${full_name} == "-bash" ]];then
        echo "${full_name}"
    else
        local file_name="$(basename ${full_name})"
        echo "${file_name}"
    fi
}

function process_exist
{
    local pid="$1"

    local ppath="/proc/${pid}/stat"
    if access_ok "${ppath}";then
        return 0
    else
        return 1
    fi
}

function process_name
{
    local pid="$1"

    # ps -p 2133 -oargs=
    # ps -p 2133 -ocomm=
    local ppath="/proc/${pid}/status"
    if access_ok "${ppath}";then
        local pname="$(cat ${ppath} | grep -w 'Name:' | awk '{ print $NF }')"
        echo "${pname}"
    else
        echo "!anon!"
    fi
}

function child_process
{
    local ppid=$1
    local chld_path="/proc/${ppid}/task/${ppid}/children"

    # ps -p $$ -o ppid=
    local child_pids=""
    if access_ok "${chld_path}"; then
        child_pids="$(cat ${chld_path})"
    fi

    echo "${child_pids}"
}

function signal_process
{
    local signal=$1
    local toppid=$2

    local child_pids=($(child_process ${toppid}))
    #echo_debug "$(process_name ${toppid})[${toppid}] childs: $(echo "${child_pids[@]}")"

    if ps -p ${toppid} > /dev/null; then
        if [ ${toppid} -ne $ROOT_PID ];then
            echo_debug "${signal}: $(process_name ${toppid})[${toppid}]"
            kill -s ${signal} ${toppid} &> /dev/null
        fi
    fi

    local index=0
    local total=${#child_pids[@]}
    while [ ${index} -lt ${total} ]
    do
        local next_pid=${child_pids[${index}]}
        if [ -z "${next_pid}" ];then
            let index++
            total=${#child_pids[@]}
        fi

        local lower_pids=($(child_process ${next_pid}))
        #echo_debug "$(process_name ${next_pid})[${next_pid}] childs: $(echo "${lower_pids[@]}")"

        if [ ${#lower_pids[@]} -gt 0 ];then
            child_pids=(${child_pids[@]} ${lower_pids[@]})
        fi

        if ps -p ${next_pid} > /dev/null; then
            if [ ${next_pid} -ne $ROOT_PID ];then
                echo_debug "${signal}: $(process_name ${next_pid})[${next_pid}]"
                kill -s ${signal} ${next_pid} &> /dev/null
            fi
        fi

        let index++
        total=${#child_pids[@]}
    done
}

function check_net
{   
    timeout=5 
    target=https://github.com

    ret_code=`curl -I -s --connect-timeout $timeout $target -w %{http_code} | tail -n1`   
    if [ "x$ret_code" = "x200" ]; then   
        return 0
    else   
        return 1
    fi 
}

function match_regex
{
    local string="$1"
    local regstr="$2"

    [ -z "${regstr}" ] && return 1 

    echo "${string}" | grep -P "${regstr}" &> /dev/null
    if [ $? -eq 0 ];then
        return 0
    else
        return 1
    fi
}

function start_chars
{
    local string="$1"
    local count="$2"

    [ -z "${count}" ] && count=1

    local chars="`echo "${string}" | cut -c 1-${count}`"
    echo "${chars}"
}

function end_chars
{
    local string="$1"
    local count="$2"

    [ -z "${count}" ] && count=1

    local chars="`echo "${string}" | rev | cut -c 1-${count} | rev`"
    echo "${chars}"
}

function match_trim_start
{
    local string="$1"
    local subchar="$2"
    
    local sublen=${#subchar}

    if [[ ${subchar} == *\\* ]];then
        subchar="${subchar//\\/\\\\}"
    fi

    if [[ ${subchar} == *\** ]];then
        subchar="${subchar//*/\*}"
    fi

    if [[ "$(start_chars "${string}" ${sublen})"x == "${subchar}"x ]]; then
        let sublen++
        local new="`echo "${string}" | cut -c ${sublen}-`" 
        echo "${new}"
    else
        echo "${string}"
    fi
}

function match_trim_end
{
    local string="$1"
    local subchar="$2"
    
    local total=${#string}
    local sublen=${#subchar}

    if [[ ${subchar} == *\\* ]];then
        subchar="${subchar//\\/\\\\}"
    fi

    if [[ ${subchar} == *\** ]];then
        subchar="${subchar//*/\*}"
    fi

    if [[ "$(end_chars "${string}" ${sublen})"x == "${subchar}"x ]]; then
        local diff=$((total-sublen))
        local new="`echo "${string}" | cut -c 1-${diff}`" 
        echo "${new}"
    else
        echo "${string}"
    fi
}

function contain_string
{
    local string="$1"
    local substr="$2"

    if [[ ${substr} == *\\* ]];then
        substr="${substr//\\/\\\\}"
    fi

    if [[ ${substr} == *\** ]];then
        substr="${substr//*/\*}"
    fi

    if [[ ${string} == *${substr}* ]];then
        return 0
    else
        return 1
    fi
}

function regex_replace
{
    local string="$1"
    local regstr="$2"
    local newstr="$3"
    
    #donot use (), because it fork child shell
    [ -z "${regstr}" ] && { echo "${string}"; return; }
 
    local oldstr=$(echo "${string}" | grep -P "${regstr}" -o | head -n 1) 
    [ -z "${oldstr}" ] && { echo "${string}"; return; }

    oldstr="${oldstr//./\.}"
    oldstr="${oldstr//\//\\/}"

    newstr="${newstr//\\/\\\\}"
    newstr="${newstr//\//\\/}"

    string="$(echo "${string}" | sed "s/${oldstr}/${newstr}/g")"
    echo "${string}"
}

function ssh_address
{
    local ssh_cli=$(echo "${SSH_CLIENT}" | grep -P "\d+\.\d+\.\d+\.\d+" -o)
    local ssh_con=$(echo "${SSH_CONNECTION}" | grep -P "\d+\.\d+\.\d+\.\d+" -o)

    for addr in ${ssh_con}
    do
        if [[ "${ssh_cli}" == "${addr}" ]];then
            continue
        fi
        echo "${addr}"
    done
}

function cursor_pos
{
    # ask the terminal for the position
    echo -ne "\033[6n" > /dev/tty

    # discard the first part of the response
    read -s -d\[ garbage < /dev/tty

    # store the position in bash variable 'pos'
    read -s -d R pos < /dev/tty

    # save the position
    #echo "current position: $pos"
    local x_pos="$(echo "${pos}" | cut -d ';' -f 1)"
    local y_pos="$(echo "${pos}" | cut -d ';' -f 2)"

    global_set_var x_pos
    global_set_var y_pos
}

COLOR_HEADER='\033[40;35m' #黑底紫字
COLOR_ERROR='\033[41;30m'  #红底黑字
COLOR_DEBUG='\033[43;30m'  #黄底黑字
COLOR_INFO='\033[42;37m'   #绿底白字
COLOR_WARN='\033[42;31m'   #蓝底红字
COLOR_CLOSE='\033[0m'      #关闭颜色
FONT_BOLD='\033[1m'        #字体变粗
FONT_BLINK='\033[5m'       #字体闪烁

function echo_header
{
    bool_v "${LOG_HEADER}"
    if [ $? -eq 0 ];then
        cur_time=`date '+%Y-%m-%d %H:%M:%S'` 
        #echo "${COLOR_HEADER}${FONT_BOLD}******${GBL_SRV_ADDR}@${cur_time}: ${COLOR_CLOSE}"
        local proc_info="$(printf "[%-12s[%5d]]" "$(file_name)" "$$")"
        echo "${COLOR_HEADER}${FONT_BOLD}${cur_time} @ ${proc_info}: ${COLOR_CLOSE}"
    fi
}

function echo_erro
{
    local para=$1
    echo -e "$(echo_header)${COLOR_ERROR}${FONT_BLINK}${para}${COLOR_CLOSE}"
}

function echo_info
{
    local para=$1
    echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE}"
}

function echo_warn
{
    local para=$1
    echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE}"
}

function echo_debug
{
    local para=$1

    if bool_v "${TEST_DEBUG}"; then
        local fname="$(file_name)"
        contain_string "${LOG_ENABLE}" "${fname}" || match_regex "${fname}" "${LOG_ENABLE}" 
        if [ $? -eq 0 ]; then
            echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE}"
        fi
    fi
}
