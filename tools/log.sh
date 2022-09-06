#!/bin/bash
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

CMD_STR="$1"
shift
while [ $# -gt 0 ]
do
    if [[ "$1" =~ ' ' ]];then
        CMD_STR="${CMD_STR} '$1'"
    else
        CMD_STR="${CMD_STR} $1"
    fi
    shift
done

#IFS_BACKUP=$IFS
#IFS=$(echo -en "\n\b")
#IFS=$(echo -en "\n\r")

echo_debug "${CMD_STR}"
bash -c "${CMD_STR}"
errcode=$?

#IFS=$IFS_BACKUP
if [ ${errcode} -ne 0 ];then
    echo_erro "errno(${errcode}): ${CMD_STR}"
fi
exit ${errcode}
