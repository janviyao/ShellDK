#!/bin/bash
: ${INCLUDE_LOG:=1}

readonly LOG_ERRO=1
readonly LOG_WARN=2
readonly LOG_INFO=3
readonly LOG_DEBUG=4

LOG_SHOW_LEVEL=3
LOG_FILE_LEVEL=3

LOG_HEADER=true
HEADER_TIME=false
HEADER_FILE=false

readonly COLOR_HEADER='\033[40;35m' #黑底紫字
readonly COLOR_ERROR='\033[41;30m'  #红底黑字
readonly COLOR_DEBUG='\033[43;30m'  #黄底黑字
readonly COLOR_INFO='\033[42;37m'   #绿底白字
readonly COLOR_WARN='\033[42;31m'   #蓝底红字
readonly COLOR_CLOSE='\033[0m'      #关闭颜色
readonly FONT_BOLD='\033[1m'        #字体变粗
readonly FONT_BLINK='\033[5m'       #字体闪烁

function echo_file
{
    local echo_level="$1"
    shift

    if [ ${LOG_FILE_LEVEL} -lt ${echo_level} ];then
        if [ ${echo_level} -le ${LOG_ERRO} ];then
            echo -e "$(print_backtrace)" >> ${BASH_LOG}
        fi
        return
    fi

    local para="$@"
    if [ $# -gt 1 ];then
        if [[ "${para}" =~ '%' ]];then
            para=$(printf "$@")
        fi
    fi

    local log_type="null"
    if [ ${echo_level} -eq ${LOG_ERRO} ];then
        log_type="erro"
    elif [ ${echo_level} -eq ${LOG_WARN} ];then
        log_type="warn"
    elif [ ${echo_level} -eq ${LOG_INFO} ];then
        log_type="info"
    elif [ ${echo_level} -eq ${LOG_DEBUG} ];then
        log_type="debug"
    fi

    local headpart=$(printf "[%5s]" "${log_type}")
    if bool_v "${LOG_HEADER}";then
        headpart=$(printf "%s[%-5s]" "$(echo_header false)" "${log_type}")
    fi

    if [ -n "${REMOTE_IP}" ];then
        #printf "%s %s from [%s]\n" "${headpart}" "$@" "${REMOTE_IP}" >> ${BASH_LOG}
        #printf "%s %s\n" "${headpart}" "${para}" >> ${BASH_LOG}
        echo -e $(printf "%s %s\n" "${headpart}" "${para}") >> ${BASH_LOG}
    else
        #printf "%s %s\n" "${headpart}" "${para}" >> ${BASH_LOG}
        echo -e $(printf "%s %s\n" "${headpart}" "${para}") >> ${BASH_LOG}
    fi

    if [ ${echo_level} -le ${LOG_ERRO} ];then
        echo -e "$(print_backtrace)" >> ${BASH_LOG}
    fi
}

function echo_header
{
    local color=${1:-true}

    if bool_v "${LOG_HEADER}";then
        local header=""
        if bool_v "${HEADER_TIME}";then
            header="[$(date '+%Y-%m-%d %H:%M:%S:%N')@$(whoami)] [${LOCAL_IP}]"
        else
            header="[${LOCAL_IP}@$(whoami)]"
        fi

        if bool_v "${HEADER_FILE}";then
            header="${header} $(printf "[%-18s[%-7d]]" "$(path2fname $0)" "$$")"
        else
            header="${header} $(printf "[%-7d]" "$$")"
        fi

        if bool_v "${color}";then
            echo "${COLOR_HEADER}${FONT_BOLD}${header}${COLOR_CLOSE} "
        else
            echo "${header} "
        fi
    fi
}

function echo_erro
{
    #local para=$(replace_str "$@" "${MY_HOME}/" "")
    if [ ${LOG_SHOW_LEVEL} -lt ${LOG_ERRO} ];then
        echo_file "${LOG_ERRO}" "$@"
        return
    fi

    local para="$@"
    if [ $# -gt 1 ];then
        if [[ "${para}" =~ '%' ]];then
            para=$(printf "$@")
        fi
    fi

    if [ -n "${REMOTE_IP}" ];then
        # echo -e "$(echo_header)${COLOR_ERROR}${FONT_BLINK}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
        echo -e "$(echo_header)${COLOR_ERROR}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
        # echo -e "$(echo_header)${COLOR_ERROR}${para}${COLOR_CLOSE}"
    else
        # echo -e "$(echo_header)${COLOR_ERROR}${FONT_BLINK}${para}${COLOR_CLOSE}"
        echo -e "$(echo_header)${COLOR_ERROR}${para}${COLOR_CLOSE}"
    fi
    echo_file "${LOG_ERRO}" "$@"
}

function echo_info
{
    if [ ${LOG_SHOW_LEVEL} -lt ${LOG_INFO} ];then
        echo_file "${LOG_INFO}" "$@"
        return
    fi

    #local para=$(replace_str "$@" "${MY_HOME}/" "")
    local para="$@"
    if [ $# -gt 1 ];then
        if [[ "${para}" =~ '%' ]];then
            para=$(printf "$@")
        fi
    fi

    if [ -n "${REMOTE_IP}" ];then
        echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
        # echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE}"
    else
        echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE}"
    fi
    echo_file "${LOG_INFO}" "$@"
}

function echo_warn
{
    if [ ${LOG_SHOW_LEVEL} -lt ${LOG_WARN} ];then
        echo_file "${LOG_WARN}" "$@"
        return
    fi

    #local para=$(replace_str "$@" "${MY_HOME}/" "")
    local para="$@"
    if [ $# -gt 1 ];then
        if [[ "${para}" =~ '%' ]];then
            para=$(printf "$@")
        fi
    fi

    if [ -n "${REMOTE_IP}" ];then
        echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
        # echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE}"
    else
        echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE}"
    fi
    echo_file "${LOG_WARN}" "$@"
}

function echo_debug
{
    if [ ${LOG_SHOW_LEVEL} -lt ${LOG_DEBUG} ];then
        echo_file "${LOG_DEBUG}" "$@"
        return
    fi

    #local para=$(replace_str "$@" "${MY_HOME}/" "")
    local para="$@"
    if [ $# -gt 1 ];then
        if [[ "${para}" =~ '%' ]];then
            para=$(printf "$@")
        fi
    fi

    if [ -n "${REMOTE_IP}" ];then
        echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
        # echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE}"
    else
        echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE}"
    fi
    echo_file "${LOG_DEBUG}" "$@"
}
