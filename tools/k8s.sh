#!/bin/bash
OPTS=$(getopt -o hc: --long help,count: -- "$@")
if [ $? != 0 ]; then
    echo_erro "options parsing Error." >&2
    exit 1
fi
eval set -- "$OPTS"

source $MY_VIM_DIR/tools/paraparser.sh "" "$@"
declare -A func_map

function list_pod
{
    local namespace="$1"

    if [ -z "${namespace}" ];then
        kubectl get pods -A -o wide
    else
        kubectl get pods -n ${namespace} -o wide
    fi

    return $?
}

func_map['list_pod']=$(cat << EOF
list_pod [namespace]

DESCRIPTION
    list all pods in the specied namespace

OPTIONS
    -h|--help                         # show this message

EXAMPLES
    list_pod                          # list all pods of all namespaces
    list_pod namespace1               # list all pods of namespace1
EOF
)

function pod_bash
{
    local pod_name="$1"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: pod name"
        return 1
    fi

    local namespace=$(kubectl get pod -A -o wide | grep -F "${pod_name}" | awk '{ print $1 }')
    if [ -z "${namespace}" ];then
        echo_erro "pod { ${pod_name} } namespace null"
        return 1
    fi

    local dockers=($(kubectl get pods -n ${namespace} ${pod_name} -o jsonpath={.spec.containers[*].name}))
    if [ ${#dockers[*]} -lt 1 ];then
        echo_erro "pod { ${pod_name} } have 0 docker"
        return 1
    fi

    local docker_name=$(select_one ${dockers[*]})
    kubectl exec -it -n ${namespace} ${pod_name} -c ${docker_name} -- bash
    return $?
}

func_map['pod_bash']=$(cat << EOF
pod_bash <pod_name>

DESCRIPTION
    enter into interface of pod bash command line

OPTIONS
    -h|--help                         # show this message

EXAMPLES
    pod_bash pod_name1
EOF
)

function pod_cmd
{
    local pod_name="$1"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: pod name\n\$2: cmd <arg1> <arg2> ... <argn>"
        return 1
    fi
    shift
    local cmd_str="$@"

    local namespace=$(kubectl get pod -A -o wide | grep -F "${pod_name}" | awk '{ print $1 }')
    if [ -z "${namespace}" ];then
        echo_erro "pod { ${pod_name} } namespace null"
        return 1
    fi

    local dockers=($(kubectl get pods -n ${namespace} ${pod_name} -o jsonpath={.spec.containers[*].name}))
    if [ ${#dockers[*]} -lt 1 ];then
        echo_erro "pod { ${pod_name} } have 0 docker"
        return 1
    fi

    local docker_name=$(select_one ${dockers[*]})
    kubectl exec -it -n ${namespace} ${pod_name} -c ${docker_name} -- ${cmd_str}
    return $?
}

func_map['pod_cmd']=$(cat << EOF
pod_cmd <pod_name> <command>

DESCRIPTION
    execute <command> in the pod <pod_name>

OPTIONS
    -h|--help                         # show this message

EXAMPLES
    pod_cmd pod_name1 ls -al
EOF
)

function pod_describe
{
    local pod_name="$1"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: pod name"
        return 1
    fi

    local namespace=$(kubectl get pod -A -o wide | grep -F "${pod_name}" | awk '{ print $1 }')
    if [ -z "${namespace}" ];then
        echo_erro "pod { ${pod_name} } namespace null"
        return 1
    fi

    kubectl describe pod -n ${namespace} ${pod_name}
    return $?
}

func_map['pod_describe']=$(cat << EOF
pod_describe <pod_name>

DESCRIPTION
    show <pod_name> descriptor information

OPTIONS
    -h|--help                         # show this message

EXAMPLES
    pod_describe pod_name1
EOF
)

function pod_log
{
    local pod_name="$1"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: pod name"
        return 1
    fi

    local namespace=$(kubectl get pod -A -o wide | grep -F "${pod_name}" | awk '{ print $1 }')
    if [ -z "${namespace}" ];then
        echo_erro "pod { ${pod_name} } namespace null"
        return 1
    fi

    local dockers=($(kubectl get pods -n ${namespace} ${pod_name} -o jsonpath={.spec.containers[*].name}))
    if [ ${#dockers[*]} -lt 1 ];then
        echo_erro "pod { ${pod_name} } have 0 docker"
        return 1
    fi

    local docker_name=$(select_one ${dockers[*]})
    kubectl logs -n ${namespace} ${pod_name} ${docker_name}
    return $?
}

func_map['pod_log']=$(cat << EOF
pod_log <pod_name>

DESCRIPTION
    show <pod_name> log

OPTIONS
    -h|--help                         # show this message

EXAMPLES
    pod_log pod_name1
EOF
)

function how_use_func
{
    local func="$1"
    local indent="$2"

    local line
    printf "%s%s\n" "${indent}" "***************************************************************"
    while read -r line
    do
        printf "%s%s\n" "${indent}" "${line}"
    done <<< "${func_map[${func}]}"
}

function how_use_tool
{
    local script_name=$(path2fname $0)

    cat <<-END >&2
    ============================== Usage ==============================
    ${script_name} <command [options] [sub-parameter]>
    DESCRIPTION
        simplify kubectl CLI usage

    COMMANDS
END

    local func
    for func in ${!func_map[*]}
    do
        how_use_func "${func}" "        "
        echo
    done
}

SUB_CMD=$(get_subcmd 0)
if [ -n "${SUB_CMD}" ];then
    tmp_list=(${!func_map[*]})
    if ! array_have tmp_list "${SUB_CMD}";then
        echo_erro "unkonw command { ${SUB_CMD} } "
        exit 1
    fi
else
    how_use_tool
    exit 1
fi

OPT_HELP=$(get_optval "-h" "--help")
if math_bool "${OPT_HELP}";then
    how_use_tool
    exit 0
fi

SUB_ALL=($(get_subcmd_all "${subcmd}"))
SUB_OPTS="${SUB_CMD} ${SUB_ALL[*]}"
SUB_LIST=($(get_subcmd "0-$"))
for subcmd in ${SUB_LIST[*]}
do
	if [ "${subcmd}" == "${SUB_CMD}" ];then
		continue
	fi

	SUB_ALL=($(get_subcmd_all "${subcmd}"))
	if [ -n "${SUB_OPTS}" ];then
		SUB_OPTS="${SUB_OPTS} ${subcmd} ${SUB_ALL[*]}"
	else
		SUB_OPTS="${subcmd} ${SUB_ALL[*]}"
	fi
done

${SUB_CMD} ${SUB_OPTS}
if [ $? -ne 0 ];then
    how_use_func "${SUB_CMD}"
fi
