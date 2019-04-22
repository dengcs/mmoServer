---------------------------------------------------------------------
--- 游戏协议解析模块
---------------------------------------------------------------------
local protobuf 	= require "protobuf"
local skynet	= require "skynet"
local lfs      	= require "lfs"

local assert	= assert
local pairs		= pairs
local tinsert 	= table.insert
local strfmt	= string.format
local ioopen	= io.open

-- 遍历指定目录（递归）
-- 1. 目录路径
-- 2. 文件后缀
-- 3. 文件集合
local function traverse(root, collect)
	collect = collect or {}
	for element in lfs.dir(root) do
		if (element ~= ".") and (element ~= "..") then
			local path = strfmt("%s/%s", root, element)
			local attr = lfs.attributes(path)
			if attr.mode == "directory" then
				traverse(path, collect)
			else
				tinsert(collect, path)
			end
		end
	end
	return collect
end

local M = {}

-- 初始化
function M.register()
	local node 	= assert(skynet.getenv("node"),"getenv获取不到node值！")
	local root 	= strfmt("./%s/lualib/config/proto/pb", node)
	local pbs	= traverse(root)
	for _,file in pairs(pbs) do
		local f = assert(ioopen(file , "rb"))
		local buffer = f:read "*a"
		f:close()

		assert(buffer)
		protobuf.register(buffer)
	end
end

-- 游戏协议编码逻辑
-- 1. 用户编号
-- 2. 协议名称
-- 3. 协议内容
-- 4. 错误码（如果存在）
function M.pb_encode(name, data, errcode)
	assert(name, "protocol is nil!!!")
	local message = 
	{
		header = { proto = name },
	}
	if errcode then
		message.error = { code = errcode }
	end
	if data then
		message.payload = protobuf.encode("game.proto." .. name, data)
	end
	return protobuf.encode("game.proto.NetMessage", message)
end

-- 游戏协议解码逻辑
-- 1. 协议信息
function M.pb_decode(data)
	local message = protobuf.decode("game.proto.NetMessage", data)
	if message.header then
		if message.header.proto then
			message.payload = protobuf.decode("game.proto." .. message.header.proto, message.payload)
			return message
		else
            LOG_ERROR(strfmt("%s : incorrect payload!!!", message.header.proto))
		end
	end
end

-- 返回协议解析模块
return M
