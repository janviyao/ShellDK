#!/bin/bash
function is_integer
{
    # is argument an integer?
    local re='^-?[0-9]+$'
    if [[ -n $1 ]]; then
        [[ $1 =~ $re ]] && return 0
        return 1
    else
        return 2
    fi
}

function is_float
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

function FLOAT
{
    local expre="$1"
    local scale="${2:-2}"
    
    echo $(echo "scale=${scale};${expre}" | bc -l | awk "{ printf \"%.${scale}f\", \$0 }")
    return 0
}

function FLOAT_IF
{
    local expre="$@"

    if [ $(echo "${expre}" | bc -l) -eq 1 ];then
        return 0
    else
        return 1
    fi
}

function NOT
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
