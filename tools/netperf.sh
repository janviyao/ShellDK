#!/bin/bash
function how_use
{
    local script_name=$(path2fname $0)
    echo "=================== Usage ==================="
    printf "%-15s <client-ip> <server-ip>\n" "${script_name}"
    printf "%-15s @%s\n" "<client-ip>" "ip address where netperf run"
    printf "%-15s @%s\n" "<server-ip>" "ip address where netserver run"
    echo "============================================="
}

if [ $# -lt 1 ];then
    how_use
    exit 1
fi

test_time=60
client_ip="$1"
server_ip="$2"

if [ $# -eq 1 ];then
    client_ip="${LOCAL_IP}"
    server_ip="$1"
fi
echo_info "netperf from { ${client_ip} } to { ${server_ip} }"

if ! match_regex "${client_ip}" "\d+\.\d+\.\d+\.\d+";then
    echo_erro "Client IP { ${client_ip} } invalid"
    exit 1
fi

if ! match_regex "${server_ip}" "\d+\.\d+\.\d+\.\d+";then
    echo_erro "Server IP { ${client_ip} } invalid"
    exit 1
fi

${MY_VIM_DIR}/tools/sshlogin.sh "${server_ip}" "process_kill netserver" 
${MY_VIM_DIR}/tools/sshlogin.sh "${server_ip}" "nohup netserver &" 

# 带宽测试：client向server发送 1024KB 大包：
${MY_VIM_DIR}/tools/sshlogin.sh "${client_ip}" "netperf -t TCP_STREAM -H ${server_ip} -l ${test_time} -- -m 1024k 'MAX_LATENCY,MEAN_LATENCY,P90_LATENCY,P99_LATENCY,P999_LATENCY,P9999_LATENCY,STDDEV_LATENCY,THROUGHPUT,THROUGHPUT_UNITS'"
# 延迟测试
# 长连接：
${MY_VIM_DIR}/tools/sshlogin.sh "${client_ip}" "netperf -t TCP_RR -H ${server_ip} -l ${test_time} -- -r 4k -O 'MIN_LAETENCY,MAX_LATENCY,MEAN_LATENCY,P90_LATENCY,P99_LATENCY,P999_LATENCY,P9999_LATENCY,STDDEV_LATENCY,THROUGHPUT,THROUGHPUT_UNITS'"
# 短连接：
${MY_VIM_DIR}/tools/sshlogin.sh "${client_ip}" "netperf -t TCP_CRR -H ${server_ip} -l ${test_time} -- -r 4k -O 'MIN_LAETENCY,MAX_LATENCY,MEAN_LATENCY,P90_LATENCY,P99_LATENCY,P999_LATENCY,P9999_LATENCY,STDDEV_LATENCY,THROUGHPUT,THROUGHPUT_UNITS'"

${MY_VIM_DIR}/tools/sshlogin.sh "${server_ip}" "process_kill netserver" 
