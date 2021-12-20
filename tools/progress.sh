#!/bin/bash
PRG_BASE_DIR="/tmp/progress"
PRG_THIS_DIR="${PRG_BASE_DIR}/pid.$$"
rm -fr ${PRG_THIS_DIR}
mkdir -p ${PRG_THIS_DIR}

PRG_PIPE="${PRG_THIS_DIR}/msg"
PRG_FD=${PRG_FD:-6}

rm -f ${PRG_PIPE}
mkfifo ${PRG_PIPE}
exec {PRG_FD}<>${PRG_PIPE} # 自动分配FD

PRG_FIN="${PRG_THIS_DIR}/finish"

PRG_SPF1="^"
PRG_SPF2="|"
function progresss_thread
{
    while read line
    do
        #echo "prg$$ recv: [${line}]"
        local order="$(echo "${line}" | cut -d "${PRG_SPF1}" -f 1)"

        if [[ "${order}" == "EXIT" ]];then
            exit 0
        elif [[ "${order}" == "FIN" ]];then
            touch ${PRG_FIN}
        fi
    done < ${PRG_PIPE}
}
progresss_thread &

function send_msg
{
    logstr="$*"
    if [ -n "${LOG_PIPE}" ] && [ -w ${LOG_PIPE} ];then
        echo "PRINT${PRG_SPF1}${logstr}" > ${LOG_PIPE}
    else
        printf "%s" "${logstr}"
    fi
}

function send_cmd
{
    cmdstr="$1"
    msgstr="$2"

    if [ -n "${LOG_PIPE}" ] && [ -w ${LOG_PIPE} ];then
        echo "${cmdstr}${PRG_SPF1}${msgstr}" > ${LOG_PIPE}
    else
        printf "%s" "${logstr}"
    fi
}

function progress
{
    local current=$1
    local total=$2

    declare -i num=$current;
    while [ $num -le $total ]
    do
        printf "\r%d" $num 
        num=$((num+1))
        sleep 0.1
    done
    echo
}

function ProgressBar()
{
    local current=$1
    local total=$2

    local now=$((current*100/total))
    local last=$(((current-1)*100/total))
    [[ $((last % 2)) -eq 1 ]] && let last++

    local str=$(for i in `seq 1 $((last/2))`; do printf '#'; done)
    for ((i=$last; $i<=$now; i+=2))
    do 
        printf "\r[%-50s]%d%%" "$str" $i
        sleep 0.1
        str+='#'
    done
}

function progress2
{
    local current=$1
    local total=$2

    for n in `seq $current $total`
    do
        ProgressBar $n $total
    done
    echo
}

function progress3
{
    local current="$1"
    local total="$2"
    local prefix="$3"

    #local step=$(printf "%.3f" `echo "scale=4;100/($total-$current+1)"|bc`)
    # here字符串
    local step=$(printf "%.3f" `bc <<< "scale=4;100/($total-$current+1)"`)

    local shrink=$((100/50))

    local now=$current
    local last=$((total+1))
    
    local postfix=('|' '/' '-' '\')
    while [[ $now -le $last ]] && [[ ! -f ${PRG_FIN} ]] 
    do
        local count=$(printf "%.0f" `echo "scale=1;(($now-$current)*$step)/$shrink"|bc`)

        local str=''
        for i in `seq 1 $count`
        do 
            str+='#'
        done

        let index=now%4
        local value=$(printf "%.0f" `echo "scale=1;($now-$current)*$step"|bc`)

        send_cmd "RETURN"
        send_msg "$(printf "%s[%-50s %-2d%% %c]" "${prefix}" "$str" "$value" "${postfix[$index]}")"

        let now++
        sleep 0.1 
    done

    # 清空输出
    send_cmd "RETURN"
    send_cmd "LOOP" "200${PRG_SPF2}SPACE"
    
    # 恢复prefix
    send_cmd "RETURN"
    send_msg "$(printf "%s" "${prefix}")"
}

PRG_CURR="$1"
PRG_LAST="$2"
LOG_PREF="$3"
LOG_PIPE="$4"

progress3 "${PRG_CURR}" "${PRG_LAST}" "${LOG_PREF}"

echo "EXIT" > ${PRG_PIPE}
wait

eval "exec ${PRG_FD}>&-"
rm -fr ${PRG_THIS_DIR}
#echo "exit prg"
