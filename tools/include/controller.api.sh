#!/bin/bash
CTRL_BASE_DIR="/tmp/ctrl"
CTRL_THIS_DIR="${CTRL_BASE_DIR}/pid.$$"
CTRL_HIGH_DIR="${CTRL_BASE_DIR}/pid.$PPID"
rm -fr ${CTRL_THIS_DIR}
mkdir -p ${CTRL_THIS_DIR} 

CTRL_THIS_PIPE="${CTRL_THIS_DIR}/msg"
LOGR_THIS_PIPE="${CTRL_THIS_DIR}/log"

CTRL_HIGH_PIPE="${CTRL_HIGH_DIR}/msg"
LOGR_HIGH_PIPE="${CTRL_HIGH_DIR}/log"

CTRL_THIS_FD=${CTRL_THIS_FD:-6}
LOGR_THIS_FD=${LOGR_THIS_FD:-7}

CTRL_SPF1="^"
CTRL_SPF2="|"

function send_ctrl_to_self
{
    local order="$1"
    local msg="$2"
    echo "${order}${CTRL_SPF1}${msg}" > ${CTRL_THIS_PIPE}
}

function send_ctrl_to_parent
{
    local order="$1"
    local msg="$2"
    echo "${order}${CTRL_SPF1}${msg}" > ${CTRL_HIGH_PIPE}
}

function send_log_to_self
{
    local order="$1"
    local msg="$2"
    echo "${order}${CTRL_SPF1}${msg}" > ${LOGR_THIS_PIPE}
}

function send_log_to_parent
{
    local order="$1"
    local msg="$2"
    echo "${order}${CTRL_SPF1}${msg}" > ${LOGR_HIGH_PIPE}
}

function controller_prepare
{
    trap - SIGINT SIGTERM EXIT

    send_ctrl_to_self "CTRL" "EXIT"
    send_log_to_self "EXIT" "this is cmd"
}

function controller_exit
{
    eval "exec ${CTRL_THIS_FD}>&-"
    eval "exec ${LOGR_THIS_FD}>&-"

    rm -fr ${CTRL_THIS_DIR}
}
