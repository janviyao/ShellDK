#!/bin/bash
: ${INCLUDED_COMMON:=1}

: ${REMOTE_IP:=}
: ${USR_NAME:=}
: ${USR_PASSWORD:=}
: ${BASH_WORK_DIR:=}
: ${GBL_MDAT_PIPE:=}
: ${GBL_LOGR_PIPE:=}
: ${GBL_NCAT_PIPE:=}
: ${GBL_XFER_PIPE:=}
: ${GBL_CTRL_PIPE:=}

function __var_defined
{
	if [[ -v $1 ]]; then
		return 0
	else
		if [[ -n $1 ]]; then
			if [[ $1 =~ ^-?[0-9]+$ ]]; then
				return 1
			fi
		else
			return 1
		fi
	fi

    ## "set -u" error will lead to shell's exit, so "$()" this will fork a child shell can solve it
    ## local check="\$(set -u ;: \$${var_name})"
    ## eval "$check" &> /dev/null
    #local arr="$(eval eval -- echo -n "\$$1")"
    #if [[ -n ${arr[*]} ]]; then
    #    # variable exist and its value is not empty
    #    return 0
    #fi
    if declare -p $1 &> /dev/null;then
        return 0
    fi

    return 1
}

function __MY_SOURCE
{
    local flag="$1"
    local file="$2"
    
    #__var_defined "${flag}" || source ${file} 
    if ! __var_defined "${flag}" && test -f ${file};then
        source ${file} 
		if [ $? -ne 0 ];then
			return 1
		fi
    fi

    return 0
}

function seq_num
{
	local _seq_num=$1
	local _max_val=$2
	local _spread=${3:-true}

	local -a _number_list=()
	if math_is_int "${_seq_num}";then
		_number_list+=("${_seq_num}")
	else
		if [[ "${_seq_num}" =~ '-' ]];then
			local -a _array_num=($(awk -F '-' '{ for (i=1; i<=NF; i++) { if ($i != "") { print $i } else { print "$" } } }' <<< "${_seq_num}"))
			local _index_s=${_array_num[0]}
			local _index_e=${_array_num[1]}
			if math_is_int "${_index_s}";then
				if math_is_int "${_index_e}";then
					if math_bool "${_spread}";then
						_number_list+=($(seq ${_index_s} ${_index_e}))
					else
						_number_list+=("${_index_s}" "${_index_e}")
					fi
				else
					if [[ "${_index_e}" == "$" ]];then
						if math_is_int "${_max_val}";then
							if math_bool "${_spread}";then
								_number_list+=($(seq ${_index_s} ${_max_val}))
							else
								_number_list+=("${_index_s}" "${_max_val}")
							fi
						else
							_number_list+=("${_index_s}" "${_index_e}")
						fi
					fi
				fi
			fi
		fi
	fi

	printf "%s\n" ${_number_list[*]}
	return 0
}

function para_pack
{
    local bash_options="$-"
    set +x
	
	local cmd=""
	if [ $# -eq 1 ];then
		cmd="$1"
		shift
	fi
	
	local have_opt=0
	while [ $# -gt 0 ]
	do
		if [[ "${1:0:1}" == "-" ]];then
			if [ -n "${cmd}" ];then
				cmd="${cmd} $1"
			else
				cmd="$1"
			fi
		else
			if [[ "$1" =~ "'" ]] || [[ "$1" =~ ">" ]] || [[ "$1" =~ "&" ]] || [[ "$1" =~ "|" ]];then
				if [[ "$1" =~ ' ' ]];then
					[[ -n "${cmd}" ]] && cmd="${cmd} \"$1\"" || cmd="\"$1\""
				else
					[[ -n "${cmd}" ]] && cmd="${cmd} $1" || cmd="$1"
				fi
			else
				if [[ "$1" =~ ' ' ]] || [[ "$1" =~ '*' ]];then
					[[ -n "${cmd}" ]] && cmd="${cmd} \"$1\"" || cmd="\"$1\""
				else
					if [ -n "${cmd}" ];then
						cmd="${cmd} $1"
					else
						cmd="$1"
					fi
				fi
			fi
		fi
		shift
	done

    [[ "${bash_options}" =~ x ]] && set -x
    echo "${cmd}"
}

function para_fetch
{
    local bash_options="$-"
    set +x

	local shortopts_refnm="$1"
    local option_all_refnm="$2"
    local subcmd_all_refnm="$3"
    local option_map_refnm="$4"

	echo_debug "$@"
    if ! is_array "$1" || ! is_array "$2" || ! is_array "$3" || ! is_map "$4";then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: array variable reference\n\$3: array variable reference\n\$4: map variable reference\n\$5~N: parameters"
		[[ "${bash_options}" =~ x ]] && set -x
        return 1
    fi
    shift 4

    local option=""
    local subcmd=""
    local value=""

    while [ $# -gt 0 ]
    do
        option=$1
        if [ -z "${option}" ] || [[ "${option}" == "--" ]];then
            shift
            continue
        fi
		value=$2

		local value_used=false
		local with_equal=false
		if [[ "${option}" =~ "=" ]];then
			with_equal=true
            value=$(string_split "${option}" '=' 2)
            option=$(string_split "${option}" '=' 1)
            if [[ "${value:0:1}" == "-" ]];then
                echo_erro "para invalid: ${option}=${value}"
				[[ "${bash_options}" =~ x ]] && set -x
                return 1
            fi
        fi

		local opt_char=""
        if [[ "${option:0:2}" == "--" ]];then
			opt_char="${option#--}"
        elif [[ "${option:0:1}" == "-" ]];then
			opt_char="${option#-}"
		fi

        echo_debug "para: \"${option}\" \"${value}\""
        if [[ "${option:0:2}" == "--" ]];then
            if [[ -z "${subcmd}" ]];then
				if [[ -n "${opt_char}" ]] && array_have ${shortopts_refnm} "${opt_char}:";then
					value_used=true
					if [[ "${value:0:1}" == "-" ]] || [[ -z "${value}" ]];then
						echo_erro "para invalid: option[${option}] no value"
						return 1
					fi

					map_add ${option_map_refnm} "${option}" "${value}"
				else
					if math_bool "${with_equal}";then
						map_add ${option_map_refnm} "${option}" "${value}"
					else
						map_add ${option_map_refnm} "${option}" true
					fi
				fi
			fi	
        elif [[ "${option:0:1}" == "-" ]];then
			if [[ -z "${subcmd}" ]];then
				if [[ -n "${opt_char}" ]] && array_have ${shortopts_refnm} "${opt_char}:";then
					value_used=true
					if [[ "${value:0:1}" == "-" ]] || [[ -z "${value}" ]];then
						echo_erro "para invalid: option[${option}] no value"
						return 1
					fi

					map_add ${option_map_refnm} "${option}" "${value}"
				else
					if math_bool "${with_equal}";then
						map_add ${option_map_refnm} "${option}" "${value}"
					else
						map_add ${option_map_refnm} "${option}" true
					fi
				fi
			fi
		else
			array_add ${subcmd_all_refnm} "${option}"
		fi

		array_add ${option_all_refnm} "${option}"
		if math_bool "${value_used}";then
			if ! math_bool "${with_equal}";then
				array_add ${option_all_refnm} "${value}"
				shift
			fi
		else
			if math_bool "${with_equal}";then
				array_add ${option_all_refnm} "${value}"
			fi
		fi
        shift
    done

	[[ "${bash_options}" =~ x ]] && set -x
    return 0
}

function export_all
{
    local local_pid=$$
    if have_cmd "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[1]}
        if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
            while [ -z "${self_pid}" ]
            do
                ppids=($(ppid))
                self_pid=${ppids[1]}
            done
        fi
        local_pid=${self_pid}
    fi

    local export_file="/tmp/export.${local_pid}"

    declare -xp &> ${export_file}
    sed -i 's/declare \-x //g' ${export_file}
    sed -i 's/declare \-ax //g' ${export_file}
    sed -i 's/declare \-Ax //g' ${export_file}
    sed -i "s/'//g" ${export_file}

    sed -i '/^[^=]\+$/d' ${export_file}
    sed -i '1 i \#!/bin/bash' ${export_file}
    sed -i '2 i \set -o allexport' ${export_file}
}

function import_all
{
    local parent_pid=$$
    if have_cmd "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[1]}
        if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
            while [ -z "${self_pid}" ]
            do
                ppids=($(ppid))
                self_pid=${ppids[1]}
            done
        fi
        parent_pid=${self_pid}
    fi

    local import_file="/tmp/export.${parent_pid}"
    if file_exist "${import_file}";then 
        local import_config=$(< "${import_file}")
        source<(echo "${import_config//\?=/=}")
    fi
}

function wait_value
{
	local -n _wait_val_ref=$1
	local resp_pipe="$2"
	local timeout_s="${3:-2}"

	if [ $# -lt 1 ];then
		echo_erro "\nUsage: [$@]\n\$1: resp_pipe\n\$2: timeout_s"
		return 1
	fi

	local try_cnt=6
	if [[ $(string_start "${timeout_s}" 1) == '+' ]]; then
		timeout_s=$(string_trim "${timeout_s}" "+" 1)
		try_cnt=$(math_round ${timeout_s} 2)
		timeout_s=2
	fi
	echo_debug "try_cnt: [${try_cnt}] timeout: [${timeout_s}s] $@"

	#echo_debug "make ack: [${resp_pipe}]"
	#file_exist "${resp_pipe}" && rm -f ${resp_pipe}
	mkfifo ${resp_pipe}
	file_exist "${resp_pipe}" || echo_erro "mkfifo: ${resp_pipe} fail"

	if have_admin && [[ "${USR_NAME}" != "root" ]];then
		chmod 777 ${resp_pipe}
	fi

	local ack_fhno=0
	exec {ack_fhno}<>${resp_pipe}

	local try_old=0
	while true
	do
		#process_run_timeout ${timeout_s} read _wait_val_ref \< ${resp_pipe}\; echo "\"\${_wait_val_ref}\"" \> ${resp_pipe}.result
		read -t ${timeout_s} _wait_val_ref < ${resp_pipe}
		echo_debug "(${try_old})read [${_wait_val_ref}] from ${resp_pipe}"

		let try_old++
		if [ -n "${_wait_val_ref}" -o ${try_old} -eq ${try_cnt} ];then
			break
		fi
	done
	eval "exec ${ack_fhno}>&-"

	if [ ${try_old} -eq ${try_cnt} ];then
		echo_debug "wait [${resp_pipe}] failed"
		return 1
	fi

	return 0
}

function send_and_wait
{
	local -n _resp_val_ref=$1
	local _resp_val_refnm=$1
    local send_body="$2"
    local send_pipe="$3"
    local timeout_s="${4:-2}"

    if [ $# -lt 2 ];then
		echo_erro "\nUsage: [$@]\n\$1: send_body\n\$2: send_pipe\n\$3: timeout_s(default: 2s)"
        return 1
    fi

    # the first pid is shell where ppid run
    local self_pid=$$
    if have_cmd "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[1]}
        if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
            while [ -z "${self_pid}" ]
            do
                ppids=($(ppid))
                self_pid=${ppids[1]}
            done
        fi
    fi

    local ack_pipe="${BASH_WORK_DIR}/ack.${self_pid}"
    while file_exist "${ack_pipe}"
    do
        ack_pipe="${BASH_WORK_DIR}/ack.${self_pid}.${RANDOM}"
    done

	echo_debug "write [NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${send_body}] to [${send_pipe}]"
	process_run_callback '' '' "process_run_with_condition 'test -p ${ack_pipe}' 'echo \"NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${send_body}\" > ${send_pipe}'" &>/dev/null

	wait_value ${_resp_val_refnm} "${ack_pipe}" "${timeout_s}"
	if [ $? -ne 0 ];then
		_resp_val_ref=""
	fi

    #echo_debug "remove: [${ack_pipe}]"
    rm -f ${ack_pipe}
    return 0
}

function input_prompt
{
    local check_func="$1"
    local prompt_ctn="$2"
    local dflt_value="$3"
    local rd_timeout="${4:-${PROMPT_TIMEOUT}}"
    local hide_hint="${5:-false}"
	local xmax ymax

    if [ $# -lt 2 ];then
		echo_erro "\nUsage: [$@]\n\$1: check function\n\$2: prompt string\n\$3: default value\n\$4: prompt timeout(default: ${PROMPT_TIMEOUT}s)\n\$5: hide hint after getting value(default: false)"
        return 1
    fi
    touch ${LOG_DISABLE}

    local extra_opt="-t ${rd_timeout}"
    if [[ "${prompt_ctn,,}" =~ 'password' ]] || [[ "${prompt_ctn,,}" =~ 'passwd' ]];then
        extra_opt="${extra_opt} -s"
    fi

	if math_bool "${hide_hint}";then
		read ymax xmax <<< $(stty size)
		local coordinate=$(cursor_pos)
		local -a pos_list=()
		array_reset pos_list "$(string_split "${coordinate}" "${GBL_VAL_SPF}")"
		local x_coord=${pos_list[0]}
		local y_coord=${pos_list[1]}
		if [[ $((y_coord + 1)) -eq ${ymax} ]];then
			y_coord=$((y_coord - 1))
		fi
	fi

    local input_val="";
    if [ -n "${dflt_value}" ];then
        read ${extra_opt} -p "Please ${prompt_ctn}(default ${dflt_value}): " input_val < /dev/tty &> /dev/tty
    else
        read ${extra_opt} -p "Please ${prompt_ctn}: " input_val < /dev/tty &> /dev/tty
    fi

	if math_bool "${hide_hint}";then
		logr_task_ctrl_sync "CURSOR_MOVE" "${x_coord}${GBL_SPF2}${y_coord}"
		logr_task_ctrl_sync "ERASE_LINE"
	fi

    if [[ -z "${input_val}" ]] && [[ -n "${dflt_value}" ]];then
        input_val="${dflt_value}"
    fi

    if [ -n "${check_func}" ];then
        while ! eval "${check_func} ${input_val}"
        do
			if math_bool "${hide_hint}";then
				coordinate=$(cursor_pos)
				local -a pos_list=()
				array_reset pos_list "$(string_split "${coordinate}" "${GBL_VAL_SPF}")"
				x_coord=${pos_list[0]}
				y_coord=${pos_list[1]}
				if [[ $((y_coord + 1)) -eq ${ymax} ]];then
					y_coord=$((y_coord - 1))
				fi
			fi

            if [ -n "${dflt_value}" ];then
                read ${extra_opt} -p "check fail, Please ${prompt_ctn}(default ${dflt_value}): " input_val < /dev/tty
            else
                read ${extra_opt} -p "check fail, Please ${prompt_ctn}: " input_val < /dev/tty &> /dev/tty
            fi

			if math_bool "${hide_hint}";then
				logr_task_ctrl_sync "CURSOR_MOVE" "${x_coord}${GBL_SPF2}${y_coord}"
				logr_task_ctrl_sync "ERASE_LINE"
			fi

            if [[ -z "${input_val}" ]] && [[ -n "${dflt_value}" ]];then
                input_val="${dflt_value}"
            fi
        done
    else
        if [ -n "${dflt_value}" ];then
            while [ -z "${input_val}" ]
            do
				if math_bool "${hide_hint}";then
					coordinate=$(cursor_pos)
					local -a pos_list=()
					array_reset pos_list "$(string_split "${coordinate}" "${GBL_VAL_SPF}")"
					x_coord=${pos_list[0]}
					y_coord=${pos_list[1]}
					if [[ $((y_coord + 1)) -eq ${ymax} ]];then
						y_coord=$((y_coord - 1))
					fi
				fi

                if [ -n "${dflt_value}" ];then
                    read ${extra_opt} -p "check fail, Please ${prompt_ctn}(default ${dflt_value}): " input_val < /dev/tty &> /dev/tty
                else
                    read ${extra_opt} -p "check fail, Please ${prompt_ctn}: " input_val < /dev/tty &> /dev/tty
                fi

				if math_bool "${hide_hint}";then
					logr_task_ctrl_sync "CURSOR_MOVE" "${x_coord}${GBL_SPF2}${y_coord}"
					logr_task_ctrl_sync "ERASE_LINE"
				fi

                if [[ -z "${input_val}" ]] && [[ -n "${dflt_value}" ]];then
                    input_val="${dflt_value}"
                fi
            done
        fi
    fi
    rm -f ${LOG_DISABLE}

    echo "${input_val}"
    return 0
}

function select_one
{
	local -a array=("$@")

    if [ ${#array[*]} -eq 0 ];then
        return 1
    fi

    local item
    local index=1
    for item in "${array[@]}"
    do
		printf -- "%2d) %s\n" "${index}" "${item}" &> /dev/tty
        let index++
    done
    
    if [ ${index} -gt 1 ];then
        let index--
    fi

    local selected=1
    local input_val=$(input_prompt "" "select one" "")
    if [ -z "${input_val}" ];then
        return 0
    fi

	while ! math_is_int "${input_val}"
	do
		local input_val=$(input_prompt "" "input number" "")
		if [ -z "${input_val}" ];then
			return 0
		fi
	done

    selected=${input_val:-${selected}}
    selected=$((selected - 1))

    echo "${array[${selected}]}"
    return 0
}

function loop2success
{
    while true
    do
		process_run "$@"
        if [ $? -eq 0 ]; then
            return 0
        fi
    done

    return 1
}

function loop2fail
{
    while true
    do
		process_run "$@"
        local retcode=$?
        if [ ${retcode} -ne 0 ]; then
            return ${retcode}
        fi
    done

    return 0
}

function progress_bar
{
    local orign="$1"
    local total="$2"
    local stop="$3"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: directory finded\n\$2: file-size filter"
        return 1
    fi

    local coordinate=$(cursor_pos)
	local -a pos_list=()
	array_reset pos_list "$(string_split "${coordinate}" "${GBL_VAL_SPF}")"
	local x_coord=${pos_list[0]}
	local y_coord=${pos_list[1]}

	local sleep_s=0.5
    local shrink=$((100 / 50))
    local move=${orign}
	local last=$(math_round "${total} - ${orign}" "${sleep_s}")
    local step=$(math_float "100 / ${last}" 5)
    
    logr_task_ctrl_async "CURSOR_MOVE" "${x_coord}${GBL_SPF2}${y_coord}"
    logr_task_ctrl_async "ERASE_LINE"
    #logr_task_ctrl_async "CURSOR_HIDE"
    
    echo_debug "pos:[${x_coord},${y_coord}] args:[$@]"
    local index percentage=0
    local postfix=('|' '/' '-' '\\')
    while [ ${move} -le ${last} ]
    do
        if eval "${stop}";then
            break
        fi

        local count=$(math_round "(${move} - 1) * ${step}" ${shrink})
        local bar_str=''
        for index in $(seq 1 ${count})
        do 
            bar_str+='+'
        done

        index=$(math_mod ${move} 4)
        percentage=$(math_float "${move} * ${step}" 2)

        logr_task_ctrl_async "CURSOR_SAVE"
        logr_task_ctrl_async "PRINT" "$(printf -- "[%-50s %-.2f%% %s]" "${bar_str}" "${percentage}" "${postfix[${index}]}")"
        logr_task_ctrl_async "CURSOR_RESTORE"

        let move++
        sleep ${sleep_s}
    done
    echo_debug "finish [%${percentage}]"

    logr_task_ctrl_async "CURSOR_MOVE" "${x_coord}${GBL_SPF2}${y_coord}"
    logr_task_ctrl_async "ERASE_LINE"
    #logr_task_ctrl_async "CURSOR_SHOW"
}

function print_lossless
{
	local string="$@"

	if [[ "${string}" =~ '%' ]];then
		string="${string//%/%%}"
	fi

	if [[ "${string}" =~ '\' ]];then
		string="${string//\\/\\\\}"
	fi

	printf -- "${string}\n"
	return 0
}

__MY_SOURCE "INCLUDED_LOG"       $MY_VIM_DIR/include/log.api.sh
if [ $? -ne 0 ];then
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi

__MY_SOURCE "INCLUDED_MATRIX"    $MY_VIM_DIR/include/matrix.api.sh
if [ $? -ne 0 ];then
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi

__MY_SOURCE "INCLUDED_STRING"    $MY_VIM_DIR/include/string.api.sh
if [ $? -ne 0 ];then
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi

__MY_SOURCE "INCLUDED_SYSTEM"    $MY_VIM_DIR/include/system.api.sh
if [ $? -ne 0 ];then
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi

__MY_SOURCE "INCLUDED_TRACE"     $MY_VIM_DIR/include/trace.api.sh
if [ $? -ne 0 ];then
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi

__MY_SOURCE "INCLUDED_KVCONF"    $MY_VIM_DIR/include/kvconf.api.sh
if [ $? -ne 0 ];then
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi

__MY_SOURCE "INCLUDED_PROCESS"   $MY_VIM_DIR/include/process.api.sh
if [ $? -ne 0 ];then
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi

__MY_SOURCE "INCLUDED_INSTALL"   $MY_VIM_DIR/include/install.api.sh
if [ $? -ne 0 ];then
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi

__MY_SOURCE "INCLUDED_MATH"      $MY_VIM_DIR/include/math.api.sh
if [ $? -ne 0 ];then
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi

__MY_SOURCE "INCLUDED_FILE"      $MY_VIM_DIR/include/file.api.sh
if [ $? -ne 0 ];then
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi

__MY_SOURCE "INCLUDED_COMPLETE"  $MY_VIM_DIR/include/complete.api.sh
if [ $? -ne 0 ];then
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi
