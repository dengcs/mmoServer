local skynet = require "skynet"
local dispatcher = require "net.dispatcher"
local userdata = require "data.userdata"
local user_meta = require "config.usermeta"

local sky_unpack = skynet.unpack

local fd_sz = string.pack(">J", 1):len()

-- 协议注册（接收'client'类型消息）
skynet.register_protocol({
	name   = "client",
	id     = skynet.PTYPE_CLIENT,
	unpack = skynet.tostring,
})

local session = nil
-- 网络消息分发器
local net_dispatcher = nil
local data_meta = nil      -- 用户数据

local CMD = {}

local function unload()
	if data_meta then
		local player = data_meta:get("Player")
		if player then
			skynet.call(GLOBAL.SERVICE_NAME.USERCENTERD, "lua", "unload", player.uid)
		end
	end
end

function CMD.init()
	net_dispatcher = dispatcher.new()

	data_meta = userdata.new("w")
	data_meta:register(user_meta)
end

function CMD.connect(source, fd, client_fd)
	session 			= {}
	session.fd 			= fd
	session.client_fd 	= client_fd
	session.data 		= data_meta
end

function CMD.disconnect()
	unload()
	session = nil

	skynet.exit()
end

function CMD.load_data(source, name, data)
	local ret_val = data_meta:init(name, data)
	if not ret_val then
		ERROR("data_meta:init(name = %s) failed!!!", name)
	end

	local result = ret_val:copy()

	return result
end

-- 内部命令转发
-- 1. 命令来源
-- 2. 命令名称
-- 3. 命令参数
local function command_handler(source, command, ...)
	if session then
		return net_dispatcher:command_dispatch(session, command, ...)
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
		skynet.error("agent---lua--"..cmd)
		local safe_handler = SAFE_HANDLER(session)
		local fn = CMD[cmd]
		if fn then
			safe_handler(fn, source, ...)
		else
			safe_handler(command_handler, source, cmd, ...)
		end
	end)
end)

-- 注册网络消息处理逻辑
skynet.dispatch("client", function(_, _, msg_data)
	msg_data = msg_data:sub(fd_sz + 1)
	local message = sky_unpack(msg_data)
	if session then
		net_dispatcher:message_dispatch(session, message)
	end
end)
