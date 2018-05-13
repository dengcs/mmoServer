#!/bin/bash

function generate() {
	## 构造模块路径
	SOURCE=$1/proto/src
	TARGET=$1/proto/pb
	## 移除过期文件
	rm -rf ${TARGET}/*.pb
	## 重构协议文件
	FPROTOS=`ls ${SOURCE} | grep .proto`
	for element in ${FPROTOS[*]}
	do
		protoc --proto_path=$1/proto ${SOURCE}/${element} -o ${TARGET}/${element/".proto"/".pb"}
	done
}

for element in `ls`
do
	m="./"${element}
	if [ -d $m ]
	then
		generate ${m}
	fi
done
