#!/bin/bash

function generate() {
	## 构造模块路径
	SOURCE=./src
	TARGET=./pb
	## 移除过期文件
	rm -rf ${TARGET}/*.pb
	## 重构协议文件
	FPROTOS=`ls ${SOURCE} | grep .proto`
	for element in ${FPROTOS[*]}
	do
		protoc ${SOURCE}/${element} -o ${TARGET}/${element/".proto"/".pb"}
	done
}

generate
