#!/bin/bash
: ${INCLUDE_K8S:=1}

function k8s_pod_get
{
    local namespace="$1"

    if [ -z "${namespace}" ];then
        kubectl get pods -A -o wide
    else
        kubectl get pods -n ${namespace} -o wide
    fi

    return $?
}

function k8s_pod_describe
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

function k8s_pod_log
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
