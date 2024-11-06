#!/bin/bash
export MY_NAME="$1"
export MY_HOME="/home/$1"
export LOCAL_IP="127.0.0.1"
export BTASK_LIST="master,mdat"
export GBL_USER_DIR="/tmp/gbl/${MY_NAME}"

function git_modify_list
{
	local file_list=($(git status --porcelain | awk '{ if( $1 == "M" ) print $2 }'))
	printf "%s\n" ${file_list[*]}
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

    if have_file "${MY_HOME}/.timerc";then
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
    if string_contain "${pid_list[*]}" "$$";then
        pid_list=($(string_replace "${pid_list[*]}" "\b$$\b" "" true))
    fi
    process_signal KILL ${pid_list[*]} &> /dev/null

    if have_file "${TEST_SUIT_ENV}";then
        source ${TEST_SUIT_ENV} 
		if [ $? -ne 0 ];then
			if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
				return 1
			else
				exit 1
			fi
		fi

        if have_file "${ISCSI_APP_LOG}";then
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

    if have_file "${BASH_LOG}";then
        logsize=$(file_size "${BASH_LOG}")
        if [ -z "${logsize}" ];then
            logsize=0
        fi
        echo_debug "timer: bash.log size= $((logsize / 1024 / 1024))MB"

        maxsize=$((300*1024*1024))
        if (( logsize > maxsize ));then
            cp -f ${BASH_LOG} ${BASH_LOG}.old
            cat /dev/null > ${BASH_LOG}
        fi
    fi

    for bash_dir in $(cd ${GBL_USER_DIR};ls -d */)
    do
        bash_pid=$(string_regex "${bash_dir}" "\d+")
        if [ -n "${bash_pid}" ];then
            if ! process_exist "${bash_pid}";then
                rm -fr ${GBL_USER_DIR}/${bash_dir}
            fi
        fi
    done
	
	file_list=($(cd ${MY_VIM_DIR}; git_modify_list))
	if [ ${#file_list[*]} -eq 0 ];then
		if [[ "${SYSTEM}" == "Linux" ]]; then
			process_run_timeout 60 sudo -u ${MY_NAME} git pull --rebase \&\>\> ${BASH_LOG}
		elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
			process_run_timeout 60 git pull --rebase \&\>\> ${BASH_LOG}
		fi
	fi

    echo_debug "timer: finish"
fi
