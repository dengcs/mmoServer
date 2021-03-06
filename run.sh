#!/bin/bash
ARENA_CMD_PORT=43002
CENTER_CMD_PORT=42002
LOGIC_CMD_PORT=41002

start(){
    ./engine/skynet config/config.${1}
    echo "${1} started"
}

stop(){
    filename=${1}.pid
    if [ -f "${filename}" ]; then
        pid=`cat ${filename}`
        kill ${pid}
        rm -f ${filename}
        echo "${1}[${pid}] stopped"
    fi
}

exit(){
    curl -s -o /dev/null "http://127.0.0.1:${1}/exit"
}

start_all(){
    start center
    start logic
    start arena
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
    exit ${ARENA_CMD_PORT}
    for((i=3;i>=1;i--));
    do
        echo ${i};
        sleep 1;
    done
    stop gate
    stop arena
    stop logic
    stop center
}

case "${1}" in
    start_center)start center;;
    start_logic)start logic;;
    start_arena)start arena;;
    start_gate)start gate;;
    stop_center)exit ${CENTER_CMD_PORT};stop center;;
    stop_logic)exit ${LOGIC_CMD_PORT};stop logic;;
    stop_arena)exit ${ARENA_CMD_PORT};stop arena;;
    stop_gate)stop gate;;
    start_all)start_all;;
    stop_all)stop_all;;
    *)
    echo "Usage : ${0} start_all|stop_all|start_center|start_logic|start_gate|stop_center|stop_logic|stop_gate"
esac