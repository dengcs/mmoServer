---------------------------------------------------------------------
--- 游戏协议解析模块
---------------------------------------------------------------------
local protobuf 	= require "protobuf"
local pbs 		= require "config.pbs"
local skynet	= require "skynet"

local M = {}

-- 初始化
function M.register()
	local node = assert(skynet.getenv("node"),"getenv获取不到node值！")
	for _,v in pairs(pbs) do
		local ok, buffer = skynet.call(GLOBAL.SERVICE_NAME.PBD, "lua", "read_buffer", node, v)
		assert(ok == 0 and buffer)
		protobuf.register(buffer)
	end
end

-- 游戏协议编码逻辑
-- 1. 用户编号
-- 2. 协议名称
-- 3. 协议内容
-- 4. 错误码（如果存在）
function M.pb_encode(uid, name, data, errcode)
	assert(name, "protocol is nil!!!")
	local message = 
	{
		header = { uid = uid, proto = name },
	}
	if errcode then
		message.error = { code = errcode }
	end
	if data then
		message.payload = protobuf.encode("game." .. name, data)
	end
	return protobuf.encode("game.NetMessage", message)
end

-- 游戏协议解码逻辑
-- 1. 协议信息
function M.pb_decode(data)
	local message = protobuf.decode("game.NetMessage", data)
	if message.header then
		if message.header.proto then
			return message, protobuf.decode("game." .. message.header.proto, message.payload)
		else
			error(string.format("%s : incorrect payload!!!", message.header.proto))
		end
	end
	return message, nil
end

-- 返回协议解析模块
return M
