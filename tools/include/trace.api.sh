#!/bin/bash
: ${PREV_BASH_OPTS:=}
: ${XTRACE_DISABLED:=}
: ${XTRACE_NESTING_LEVEL:=}

function print_backtrace
{
    # if errexit is not enabled, don't print a backtrace
    #[[ "$-" =~ e ]] || return 0
    local shell_options="$-"
    set +x
    if [ ${#FUNCNAME[*]} -gt 0 ];then
        echo "========== Backtrace start: =========="
        echo ""
        for i in $(seq 1 $((${#FUNCNAME[*]} - 1)))
        do
            local func="${FUNCNAME[$i]}"
            if [[ ${func} == echo_erro ]] || [[ ${func} == echo_file ]];then
                continue
            fi

            local line_nr="${BASH_LINENO[$((i - 1))]}"
            local src="${BASH_SOURCE[$i]}"
            if [ -z "${src}" ];then
                echo "in ${line_nr} -> ${func}()"
                continue
            fi

            echo "in ${src}:${line_nr} -> ${func}()"
            echo "     ..."
            nl -w 4 -ba -nln ${src} 2>/dev/null | grep -B 5 -A 5 "^${line_nr}[^0-9]" | sed "s/^/   /g" | sed "s/^   ${line_nr} /=> ${line_nr} /g"
            echo "     ..."
        done
        echo ""
        echo "========== Backtrace end =========="
    fi
    [[ "${shell_options}" =~ x ]] && set -x

    return 0
}

function enable_backtrace
{
    # Same as -E.
    # -E If set, any trap on ERR is inherited by shell functions,
    # command substitutions, and commands executed in a sub‐shell environment.  
    # The ERR trap is normally not inherited in such cases.
    #set -o xtrace
    #set -x 
    #set -o errexit
    #set -e 
    set -o errtrace
    trap "trap - ERR; print_backtrace >&2" ERR
}

function disable_backtrace
{
    #set +e
    set +o errtrace
}

function xtrace_fd() 
{
    if [[ -n $BASH_XTRACEFD && -e /proc/self/fd/$BASH_XTRACEFD ]]; then
        # Close it first to make sure it's sane
        exec {BASH_XTRACEFD}>&-
    fi
    exec {BASH_XTRACEFD}>&2

    set -x
}

function xtrace_disable() 
{
    if [ "${XTRACE_DISABLED}" != "yes" ]; then
        PREV_BASH_OPTS="$-"
        if [[ "${PREV_BASH_OPTS}" == *"x"* ]]; then
            XTRACE_DISABLED="yes"
        fi
        set +x
    elif [ -z ${XTRACE_NESTING_LEVEL} ]; then
        XTRACE_NESTING_LEVEL=1
    else
        XTRACE_NESTING_LEVEL=$((++XTRACE_NESTING_LEVEL))
    fi
}

# Dummy function to be called after restoring xtrace just so that it appears in the
# xtrace log. This way we can consistently track when xtrace is enabled/disabled.
function xtrace_enable() 
{
    # We have to do something inside a function in bash, and calling any command
    # (even `:`) will produce an xtrace entry, so we just define another function.
    function xtrace_dummy() { :; }
}

# Keep it as alias to avoid xtrace_enable backtrace always pointing to xtrace_restore.
# xtrace_enable will appear as called directly from the user script, from the same line
# that "called" xtrace_restore.
#alias xtrace_restore='if [ -z ${XTRACE_NESTING_LEVEL} ]; then
#        if [[ "${PREV_BASH_OPTS}" == *"x"* ]]; then
#        XTRACE_DISABLED="no"; PREV_BASH_OPTS=""; set -x; xtrace_enable;
#    fi
#else
#    XTRACE_NESTING_LEVEL=$((--XTRACE_NESTING_LEVEL));
#    if [ ${XTRACE_NESTING_LEVEL} -eq "0" ]; then
#        unset XTRACE_NESTING_LEVEL
#    fi
#fi'
function xtrace_restore()
{
    if [ -z ${XTRACE_NESTING_LEVEL} ]; then
        if [[ "${PREV_BASH_OPTS}" == *"x"* ]]; then
            XTRACE_DISABLED="no"; PREV_BASH_OPTS=""; set -x; xtrace_enable;
        fi
    else
        XTRACE_NESTING_LEVEL=$((--XTRACE_NESTING_LEVEL));
        if [ ${XTRACE_NESTING_LEVEL} -eq "0" ]; then
            unset XTRACE_NESTING_LEVEL
        fi
    fi
}

#shopt -s extdebug
#set -o errtrace
#trap "trap - ERR; print_backtrace >&2" ERR
#PS4='\t -- ${BASH_SOURCE#${BASH_SOURCE%/*/*}/}@${LINENO} -- \$ '
# : ${XTRACE_AUTO:=false}
# if ${XTRACE_AUTO}; then
#     xtrace_restore
# else
#     # explicitly enable xtraces, overriding any tracking information.
#     unset XTRACE_DISABLED
#     unset XTRACE_NESTING_LEVEL
#     xtrace_fd
#     xtrace_disable
# fi
