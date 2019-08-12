#!/bin/bash
CENTER_CMD_PORT=42002
LOGIC_CMD_PORT=41002

start(){
    ./engine/skynet config/config.${1}
    echo "${1} started"
}

stop(){
    pid=`cat ${1}.pid`
    kill ${pid}
    echo "${1}[${pid}] stopped"
}

exit(){
    curl -s -o /dev/null "http://127.0.0.1:${1}/exit"
}

start_all(){
    start center
    start logic
    for((i=3;i>=1;i--));
    do
    echo ${i};
    sleep 1;
    done
    start gate
}

stop_all(){
    exit ${CENTER_CMD_PORT}
    exit ${LOGIC_CMD_PORT}
    for((i=3;i>=1;i--));
    do
    echo ${i};
    sleep 1;
    done
    stop gate
    stop logic
    stop center
}

case "${1}" in
    start_center)start center;;
    start_logic)start logic;;
    start_gate)start gate;;
    stop_center)exit ${CENTER_CMD_PORT};stop center;;
    stop_logic)exit ${LOGIC_CMD_PORT};stop logic;;
    stop_gate)stop gate;;
    start_all)start_all;;
    stop_all)stop_all;;
    *)
    echo "Usage : ${0} start_all|stop_all|start_center|start_logic|start_gate|stop_center|stop_logic|stop_gate"
esac