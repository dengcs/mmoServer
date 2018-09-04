---------------------------------------------------------------------
--- 游戏协议解析模块
---------------------------------------------------------------------
local protobuf = require "protobuf"

local M = {}

-- 游戏协议注册
-- 1. 协议集合
function M.register(protocols)
	for _, name in pairs(protocols) do
		protobuf.register_file(name)
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
	print("dcs--"..table.tostring(message))
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
