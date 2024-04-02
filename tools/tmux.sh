#!/bin/bash
. $MY_VIM_DIR/tools/paraparser.sh

function how_use
{
    local script_name=$(path2fname $0)

	cat <<-END >&2
    ============================== Usage ==============================
    ${script_name} [options] <command [sub-parameter]>
    DESCRIPTION
        simplify tmux usage

    COMMANDS
        help                              # show this message
        new <session-name>                # create a tmux session
        list|ls                           # list all tmux sessions
        attach|att [session-name]         # attach to the specific session
        detach|det|leave                  # detach from the current session or shortcut: <ctrl+b>+d
        delete|del|exit [session-name]    # delete the specific session

    OPTIONS
        -h|--help                         # show this message

    EXAMPLES
        mytmux list
        mytmux attach session1
        mytmux detach
        mytmux del session1
    ===================================================================
END
}

if [ -z "$(get_subopt '*')" ];then
    how_use
    exit 1
fi

OPT_HELP=$(get_options "-h" "--help")
if math_bool "${OPT_HELP}";then
    how_use
    exit 0
fi

SUB_CMD=$(get_subopt 0)
SUB_PARA1=$(get_subopt 1)
case ${SUB_CMD} in
    new)
        if [ -n "${SUB_PARA1}" ];then
            tmux new-session -s ${SUB_PARA1}
        else
            tmux new-session
        fi
        ;;
    list|ls)
        tmux list-sessions
        ;;
    attach|att)
        if [ -n "${SUB_PARA1}" ];then
            if tmux has-session -t ${SUB_PARA1} &> /dev/null;then
                tmux attach-session -t ${SUB_PARA1}
            fi
        fi
        ;;
    dettach|det|leave)
        tmux detach-client
        ;;
    delete|del|exit)
        if [ -n "${SUB_PARA1}" ];then
            if tmux has-session -t ${SUB_PARA1} &> /dev/null;then
                tmux kill-session -t ${SUB_PARA1}
            fi
        else
            how_use
            exit 1
        fi
        ;;
    *)
        how_use
        exit 1
        ;;
esac
