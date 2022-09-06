#!/bin/bash
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"
IFS_BACKUP=$IFS
#IFS=$(echo -en "\n\b")
IFS=$(echo -en "\n\r")

if bool_v "${LOG_OPEN}";then
    echo "$@"
    eval "$@"
else
    if var_exist "BASH_LOG";then
        eval "$@" >> ${BASH_LOG} 2>&1
    else
        eval "$@" >> log 2>&1
    fi
fi
errcode=$?

IFS=$IFS_BACKUP
if [ ${errcode} -ne 0 ];then
    echo_erro "errno(${errcode}): $@"
fi

exit ${errcode}
