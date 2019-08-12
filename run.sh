#!/bin/bash

start(){
    ./engine/skynet config/config.${1}
    echo "${1} started"
}

stop(){
    pid=`cat ${1}.pid`
    kill ${pid}
    echo "${1}[${pid}] stopped"
}

case "${1}" in
    start_center)start center;;
    start_logic)start logic;;
    start_gate)start gate;;
    stop_center)stop center;;
    stop_logic)stop logic;;
    stop_gate)stop gate;;
    *)
    echo "Usage : ${0} start_center|start_logic|start_gate|stop_center|stop_logic|stop_gate"
esac