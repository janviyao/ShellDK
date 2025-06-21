#!/bin/bash
export MY_NAME="$1"
export MY_HOME="/home/$1"
export LOCAL_IP="127.0.0.1"
export BTASK_LIST="master"
export GBL_USER_DIR="/tmp/gbl/${MY_NAME}"

function git_modify_list
{
	local file_list=($(git status --porcelain | awk '{ if( $1 == "M" ) print $2 }'))
	printf -- "%s\n" ${file_list[*]}
}

if [ -f ${GBL_USER_DIR}/timer/.timerc ];then
    source ${GBL_USER_DIR}/timer/.timerc
	if [ $? -ne 0 ];then
		echo_debug "timer: exception exit"
		if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
			return 1
		else
			exit 1
		fi
	fi

    source ${MY_VIM_DIR}/bashrc
	if [ $? -ne 0 ];then
		echo_debug "timer: exception exit"
		if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
			return 1
		else
			exit 1
		fi
	fi

    if file_exist "${MY_HOME}/.timerc";then
		source ${MY_HOME}/.timerc
		if [ $? -ne 0 ];then
			echo_debug "timer: exception exit"
			if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
				return 1
			else
				exit 1
			fi
		fi
    else
        exit 0
    fi

	pid_list=($(process_name2pid timer.sh))
	array_del_by_value pid_list $$
	for pid in "${pid_list[@]}"
	do
		if ! process_exist ${pid};then
			array_del_by_value pid_list ${pid}
		fi
	done

	if [ ${#pid_list[*]} -gt 0 ];then
		process_signal KILL ${pid_list[*]} &> /dev/null
	fi

    if file_exist "${TEST_SUIT_ENV}";then
        source ${TEST_SUIT_ENV} 
		if [ $? -ne 0 ];then
			if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
				return 1
			else
				exit 1
			fi
		fi

        if file_exist "${ISCSI_APP_LOG}";then
            logsize=$(file_size "${ISCSI_APP_LOG}")
            if [ -z "${logsize}" ];then
                logsize=0
            fi

            maxsize=$((600*1024*1024))
            if (( logsize > maxsize ));then
                date_time=$(date '+%Y%m%d-%H%M%S')
                cp -f ${ISCSI_APP_LOG} ${ISCSI_APP_LOG}.${date_time}
                #truncate -s 0 ${ISCSI_APP_LOG}
                cat /dev/null > ${ISCSI_APP_LOG}
            fi
        fi
    fi

    if file_exist "${BASH_LOG}";then
        logsize=$(file_size "${BASH_LOG}")
        if [ -z "${logsize}" ];then
            logsize=0
        fi
        echo_debug "timer: bash.log size= $((logsize / 1024 / 1024))MB"

		if math_expr_if "${logsize} > (100 * 1024 * 1024)";then
			line_num=$(file_line_num ${BASH_LOG})
			line_num=$(math_expr_val "${line_num} - (${line_num} / 100)" 0)
			file_del ${BASH_LOG} "1-${line_num}"
        fi
    fi

    for bash_dir in $(cd ${GBL_USER_DIR};ls -d */)
    do
        bash_pid=$(string_gensub "${bash_dir}" "\d+")
        if [ -n "${bash_pid}" ];then
            if ! process_exist "${bash_pid}";then
                rm -fr ${GBL_USER_DIR}/${bash_dir}
            fi
        fi
    done

	cd ${MY_VIM_DIR}
	file_list=($(git_modify_list))
	if [ ${#file_list[*]} -eq 0 ];then
		process_run_timeout 300 git pull --rebase \&\> /dev/null \|\| exit 0
	fi

    echo_debug "timer: finish"
else
    pid_list=($(pgrep -x timer.sh))
    sudo -n kill -9 ${pid_list[*]} &> /dev/null
fi
