#!/bin/bash
: ${INCLUDED_MATH:=1}

function math_is_int
{
    # is argument an integer?
    local re='^-?[0-9]+$'
    if [[ -n $1 ]]; then
        [[ $1 =~ $re ]] && return 0
        re='^(0[xX])?[0-9a-fA-F]+$'
        [[ $1 =~ $re ]] && return 0
        return 1
    else
        return 2
    fi
}

function math_is_float
{
    # is argument an integer?
    local re='^-?[0-9]+\.?[0-9]+$'
    if [[ -n $1 ]]; then
        [[ $1 =~ $re ]] && return 0
        return 1
    else
        return 2
    fi
}

function math_char2ascii
{
	printf -- "%d\n" "'$1"
}

function math_ascii2char
{
	printf -- "\\$(printf '%03o' "$1")"
}

function math_bool
{
    local bash_options="$-"
    set +x

    local expr="$@"

    if [[ $# -gt 1 ]];then
        math_expr_if "${expr}"
        local ret=$?
        [[ "${bash_options}" =~ x ]] && set -x
        return ${ret}
    fi

    if [[ "${expr,,}" == "yes" ]] || [[ "${expr,,}" == "true" ]] || [[ "${expr,,}" == "y" ]] || [[ "${expr,,}" == "1" ]]; then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    elif [[ "${expr,,}" == "no" ]] || [[ "${expr,,}" == "false" ]] || [[ "${expr,,}" == "n" ]] || [[ "${expr,,}" == "0" ]]; then
        [[ "${bash_options}" =~ x ]] && set -x
        return 1
    else
        math_expr_if "${expr}"
        local ret=$?
        [[ "${bash_options}" =~ x ]] && set -x
        return ${ret}
    fi
}

function math_expr_if
{
    local expre="$@"

    if [[ $(echo "scale=0;${expre}" | bc -l) -ge 1 ]];then
        return 0
    else
        return 1
    fi
}

function math_expr_val
{
	local bash_options="$-"
	set +x

	local expre="$1"
	local scale=${2:-4}
	local ibase=${3:-10}
	
	if [ ${ibase} -eq 16 ];then
		expre=${expre^^}
	fi

	local value=$(bc -l <<< "ibase=${ibase};scale=$((scale+2));(${expre})/1")
	if [[ ${value} =~ ^\.[0-9]+$ ]];then
		value="0${value}"
	fi

	if [[ ${value} =~ ^[0-9]+(\.[0-9]+)?$ ]];then
		value=$(awk "BEGIN { printf \"%.${scale}f\n\", ${value} }")
		if [[ ${value} =~ ^\.[0-9]+$ ]];then
			value="0${value}"
		fi
	fi

	echo "${value}"
	[[ "${bash_options}" =~ x ]] && set -x
	return 0
}

function math_float
{
    local expre="$1"
    local scale="${2:-2}"
    
    echo $(echo "scale=8;(${expre})/1.0" | bc -l | awk "{ printf \"%.${scale}f\", \$0 }")
    return 0
}

function math_mod
{
    local expre="$1"
    local divisor="$2"

    if [[ $# -ne 2 ]];then
        echo_erro "\nUsage: [$@]\n\$1: one integer\n\$2: divisor value"
        return 1
    fi

    if ! math_is_int "${divisor}";then
        echo_erro "\nUsage: [$@]\n\$1: one integer\n\$2: whether to be uppercase(default: true)"
        return 1
    fi

    echo $(echo "scale=0;(${expre})%${divisor}" | bc -l)
    return 0
}

function math_round
{
    local expre="$1"
    local divisor="$2"

    if [[ $# -ne 2 ]];then
        echo_erro "\nUsage: [$@]\n\$1: one integer\n\$2: divisor value"
        return 1
    fi

    if ! math_is_int "${divisor}";then
        echo_erro "\nUsage: [$@]\n\$1: one integer\n\$2: whether to be uppercase(default: true)"
        return 1
    fi

    echo $(echo "scale=0;(${expre})/${divisor}" | bc -l)
    return 0
}

function math_dec2bin
{
    local value="$1"

    if [[ $# -lt 1 ]];then
        echo_erro "\nUsage: [$@]\n\$1: one integer"
        return 1
    fi

    if ! math_is_int "${value}";then
        echo_erro "\nUsage: [$@]\n\$1: one integer"
        return 1
    fi

    local result=""
    while true
    do
        local modulo=$(math_mod "${value}" 2) 
        value=$(math_round "${value}" 2) 

        result=${modulo}${result}
        if [ "${value}" -le 0 ];then
            break
        fi
    done
    [ -n "${result}" ] && echo "${result}"

    return 0
}

function math_dec2hex
{
    local value="$1"
    local upper="${2:-true}"

    if [[ $# -lt 1 ]] || [[ $# -gt 2 ]];then
        echo_erro "\nUsage: [$@]\n\$1: one integer\n\$2: whether to be uppercase(default: true)"
        return 1
    fi

    if ! math_is_int "${value}";then
        echo_erro "\nUsage: [$@]\n\$1: one integer\n\$2: whether to be uppercase(default: true)"
        return 1
    fi

    local result=$(printf -- "0x%llx" ${value})
    if [ -n "${result}" ];then
        if math_bool "${upper}";then
            echo "${result^^}"
        else
            echo "${result,,}"
        fi
    fi

    return 0
}

function math_bin2dec
{
    local value="$1"

    if [[ $# -lt 1 ]];then
        echo_erro "\nUsage: [$@]\n\$1: one binary-number"
        return 1
    fi
    [ -z "${value}" ] && return 1

    local base=1
    local result=0

    local max_index=$(string_length "${value}")
    local index=$((max_index - 1))
    while [ ${index} -gt 0 ]
    do
        local char=$(string_char "${value}" ${index}) 
        if [[ ${char} == 1 ]];then
            result=$(echo "${result} + ${base} * ${char}" | bc -l)
        fi
        base=$(echo "${base} * 2" | bc -l)
        let index--
    done

    local char=$(string_char "${value}" ${index}) 
    if [[ ${char} == 1 ]];then
        result=$(echo "${result} + ${base} * ${char}" | bc -l)
    fi

    [ -n "${result}" ] && echo "${result}"
    return 0
}

function math_hex2dec
{
    local value="$1"
    local result=0

    if [[ $# -lt 1 ]];then
        echo_erro "\nUsage: [$@]\n\$1: one hex-number"
        return 1
    fi

	local prestr=$(string_start "${value}" 2)
	if [[ ${prestr,,} == '0x' ]];then
		result=$(printf -- "%lld" ${value})
		if [ $? -ne 0 ];then
			result=""
		fi

		if [ -n "${result}" ];then
			echo "${result}"
		fi
	else
		echo $((16#${value}))
	fi

    return 0
}

function math_hex2bin
{
    local value="$1"

    if [[ $# -lt 1 ]];then
        echo_erro "\nUsage: [$@]\n\$1: one hex-number"
        return 1
    fi

    local prestr=$(string_start "${value}" 2)
    if [[ ${prestr,,} != '0x' ]]; then
        value="0x${value}"
    fi

    local result=$(math_hex2dec "${value}")
    [ -n "${result}" ] && result=$(math_dec2bin "${result}")
    [ -n "${result}" ] && echo "${result}"

    return 0
}

function math_lshift
{
    local value="$1"
    local shiftv="$2"

    if [[ $# -lt 2 ]];then
        echo_erro "\nUsage: [$@]\n\$1: one decimal integer\n\$2: left shift count"
        return 1
    fi

    if ! math_is_int "${value}";then
        echo_erro "\nUsage: [$@]\n\$1: one decimal integer\n\$2: left shift count"
        return 1
    fi

    if ! math_is_int "${shiftv}";then
        echo_erro "\nUsage: [$@]\n\$1: one decimal integer\n\$2: left shift count"
        return 1
    fi

    echo $((value << shiftv))
    return 0
}

function math_rshift
{
    local value="$1"
    local shiftv="$2"

    if [[ $# -lt 2 ]];then
        echo_erro "\nUsage: [$@]\n\$1: one decimal integer\n\$2: right shift count"
        return 1
    fi

    if ! math_is_int "${value}";then
        echo_erro "\nUsage: [$@]\n\$1: one decimal integer\n\$2: right shift count"
        return 1
    fi

    if ! math_is_int "${shiftv}";then
        echo_erro "\nUsage: [$@]\n\$1: one decimal integer\n\$2: right shift count"
        return 1
    fi

    echo $((value >> shiftv))
    return 0
}

function math_not
{
    local es=0

    "$@" || es=$?

    # Logic looks like so:
    #  - return false if command exit successfully
    #  - return false if command exit after receiving a core signal (FIXME: or any signal?)
    #  - return true if command exit with an error

    # This naively assumes that the process doesn't exit with > 128 on its own.
    if ((es > 128)); then
        es=$((es & ~128))
        case "$es" in
            3) ;&       # SIGQUIT
            4) ;&       # SIGILL
            6) ;&       # SIGABRT
            8) ;&       # SIGFPE
            9) ;&       # SIGKILL
            11) es=0 ;; # SIGSEGV
            *) es=1 ;;
        esac
    elif [[ -n $EXIT_STATUS ]] && ((es != EXIT_STATUS)); then
        es=0
    fi

    # invert error code of any command and also trigger ERR on 0 (unlike bash ! prefix)
    ((!es == 0))
}
