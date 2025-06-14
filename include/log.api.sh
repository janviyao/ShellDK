#!/bin/bash
: ${INCLUDED_LOG:=1}

readonly LOG_ERRO=1
readonly LOG_WARN=2
readonly LOG_INFO=3
readonly LOG_DEBUG=4

LOG_SHOW_LEVEL=3
LOG_FILE_LEVEL=4

LOG_HEADER=true
HEADER_TIME=true
HEADER_FILE=false

readonly COLOR_HEADER='\033[40;35m' #黑底紫字
readonly COLOR_ERROR='\033[41;30m'  #红底黑字
readonly COLOR_DEBUG='\033[43;30m'  #黄底黑字
readonly COLOR_INFO='\033[42;37m'   #绿底白字
readonly COLOR_WARN='\033[42;31m'   #蓝底红字
readonly COLOR_CLOSE='\033[0m'      #关闭颜色
readonly FONT_BOLD='\033[1m'        #字体变粗
readonly FONT_BLINK='\033[5m'       #字体闪烁

function cecho
{
    local mode="$1"
    shift

    local code="\033["
    case "${mode}" in
        black  | bk) color="${code}0;30m";;
        red    |  r) color="${code}1;31m";;
        green  |  g) color="${code}1;32m";;
        yellow |  y) color="${code}1;33m";;
        blue   |  b) color="${code}1;34m";;
        purple |  p) color="${code}1;35m";;
        cyan   |  c) color="${code}1;36m";;
        gray   | gr) color="${code}0;37m";;
        *) local text="${mode} $@"
    esac

    if [ -z "${text}" ];then
        local text="${color}$@${code}0m"
    fi
    echo -e "${text}"
}

function echo_file
{
    local bash_options="$-"
    set +x

    local echo_level="$1"
    shift

    if [ ${LOG_FILE_LEVEL} -lt ${echo_level} ];then
        if [ ${echo_level} -le ${LOG_ERRO} ];then
            echo -e "$(print_backtrace)" >> ${BASH_LOG}
        fi
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    fi

    local para="$@"
    if [ $# -gt 1 ];then
        if [[ "${para}" =~ '%' ]];then
            para=$(printf -- "$@")
        fi
    fi

    local log_type="NOTICE"
    if [ ${echo_level} -eq ${LOG_ERRO} ];then
        log_type="ERROR"
    elif [ ${echo_level} -eq ${LOG_WARN} ];then
        log_type="WARN"
    elif [ ${echo_level} -eq ${LOG_INFO} ];then
        log_type="INFO"
    elif [ ${echo_level} -eq ${LOG_DEBUG} ];then
        log_type="DEBUG"
    fi

	local func_name=${FUNCNAME[1]}
	if [[ ${func_name} =~ ^echo_ ]];then
		func_name=${FUNCNAME[2]}
	fi

    local headpart=$(printf -- "[%-5s] [%s]" "${log_type}" "${func_name}")
    if math_bool "${LOG_HEADER}";then
        headpart=$(printf -- "%s[%-5s] [%s]" "$(echo_header false)" "${log_type}" "${func_name}")
    fi

    if [ -n "${REMOTE_IP}" ];then
        #printf "%s %s from [%s]\n" "${headpart}" "$@" "${REMOTE_IP}" >> ${BASH_LOG}
        #printf "%s %s\n" "${headpart}" "${para}" >> ${BASH_LOG}
        echo -e $(printf -- "%s %s\n" "${headpart}" "${para}") >> ${BASH_LOG}
    else
        #printf "%s %s\n" "${headpart}" "${para}" >> ${BASH_LOG}
        echo -e $(printf -- "%s %s\n" "${headpart}" "${para}") >> ${BASH_LOG}
    fi

    if [ ${echo_level} -le ${LOG_ERRO} ];then
        echo -e "$(print_backtrace)" >> ${BASH_LOG}
    fi
    [[ "${bash_options}" =~ x ]] && set -x

    if [ ${echo_level} -eq ${LOG_ERRO} ];then
		return 1 
    fi
    return 0
}

function echo_header
{
    local color=${1:-true}

    if math_bool "${LOG_HEADER}";then
        local header=""
        if math_bool "${HEADER_TIME}";then
            #header="[$(date '+%Y-%m-%d %H:%M:%S:%N')@${MY_NAME}] [${LOCAL_IP}]"
            header="[$(date '+%Y-%m-%d %H:%M:%S:%N')]"
        else
            header="[${LOCAL_IP}@${MY_NAME}]"
        fi

        if math_bool "${HEADER_FILE}";then
            header="${header} $(printf -- "[%-18s[%7d]]" "$(file_get_fname $0)" "$$")"
        else
            header="${header} $(printf -- "[%7d]" "$$")"
        fi

        if math_bool "${color}";then
            echo "${COLOR_HEADER}${FONT_BOLD}${header}${COLOR_CLOSE} "
        else
            echo "${header} "
        fi
    fi
}

function echo_erro
{
    local bash_options="$-"
    set +x

    #local para=$(string_replace "$@" "${MY_HOME}/" "")
    if [ ${LOG_SHOW_LEVEL} -lt ${LOG_ERRO} ];then
        echo_file "${LOG_ERRO}" "$@"
        [[ "${bash_options}" =~ x ]] && set -x
        return 1
    fi

    local para="$@"
    if [ $# -gt 1 ];then
        if [[ "${para}" =~ '%' ]];then
            para=$(printf -- "$@")
        fi
    fi

    if ! file_exist "${LOG_DISABLE}";then
        if [ -n "${REMOTE_IP}" ];then
            # echo -e "$(echo_header)${COLOR_ERROR}${FONT_BLINK}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
            echo >&2 -e "$(echo_header)${COLOR_ERROR}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
            # echo -e "$(echo_header)${COLOR_ERROR}${para}${COLOR_CLOSE}"
        else
            # echo -e "$(echo_header)${COLOR_ERROR}${FONT_BLINK}${para}${COLOR_CLOSE}"
            echo >&2 -e "$(echo_header)${COLOR_ERROR}${para}${COLOR_CLOSE}"
        fi
    fi

    echo_file "${LOG_ERRO}" "$@"
    [[ "${bash_options}" =~ x ]] && set -x
    return 1
}

function echo_info
{
    local bash_options="$-"
    set +x

    if [ ${LOG_SHOW_LEVEL} -lt ${LOG_INFO} ];then
        echo_file "${LOG_INFO}" "$@"
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    fi

    #local para=$(string_replace "$@" "${MY_HOME}/" "")
    local para="$@"
    if [ $# -gt 1 ];then
        if [[ "${para}" =~ '%' ]];then
            para=$(printf -- "$@")
        fi
    fi

    if ! file_exist "${LOG_DISABLE}";then
        if [ -n "${REMOTE_IP}" ];then
            echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
            # echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE}"
        else
            echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE}"
        fi
    fi

    echo_file "${LOG_INFO}" "$@"
    [[ "${bash_options}" =~ x ]] && set -x
    return 0
}

function echo_warn
{
    local bash_options="$-"
    set +x

    if [ ${LOG_SHOW_LEVEL} -lt ${LOG_WARN} ];then
        echo_file "${LOG_WARN}" "$@"
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    fi

    #local para=$(string_replace "$@" "${MY_HOME}/" "")
    local para="$@"
    if [ $# -gt 1 ];then
        if [[ "${para}" =~ '%' ]];then
            para=$(printf -- "$@")
        fi
    fi

    if ! file_exist "${LOG_DISABLE}";then
        if [ -n "${REMOTE_IP}" ];then
            echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
            # echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE}"
        else
            echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE}"
        fi
    fi

    echo_file "${LOG_WARN}" "$@"
    [[ "${bash_options}" =~ x ]] && set -x
    return 0
}

function echo_debug
{
    local bash_options="$-"
    set +x

    if [ ${LOG_SHOW_LEVEL} -lt ${LOG_DEBUG} ];then
        echo_file "${LOG_DEBUG}" "$@"
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    fi

    #local para=$(string_replace "$@" "${MY_HOME}/" "")
    local para="$@"
    if [ $# -gt 1 ];then
        if [[ "${para}" =~ '%' ]];then
            para=$(printf -- "$@")
        fi
    fi

    if ! file_exist "${LOG_DISABLE}";then
        if [ -n "${REMOTE_IP}" ];then
            echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
            # echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE}"
        else
            echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE}"
        fi
    fi

    echo_file "${LOG_DEBUG}" "$@"
    [[ "${bash_options}" =~ x ]] && set -x
    return 0
}

function echo_die
{
    local bash_options="$-"
    set +x

    echo_erro "$@"

    [[ "${bash_options}" =~ x ]] && set -x
    exit 1
}
