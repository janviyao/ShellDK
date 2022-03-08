#!/bin/bash
IFS_BACKUP=$IFS
#IFS=$(echo -en "\n\b")
IFS=$(echo -en "\n\r")

if bool_v "${DEBUG_ON}";then
    echo $*
    $*
else
    if var_exist "LOG_FILE";then
        $* >> ${LOG_FILE} 2>&1
    else
        $* >> log 2>&1
    fi
fi
errcode=$?

IFS=$IFS_BACKUP
if [ ${errcode} -ne 0 ];then
    echo_erro "errno(${errcode}): $*"
fi

exit ${errcode}
