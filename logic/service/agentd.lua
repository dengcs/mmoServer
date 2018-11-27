local skynet = require "skynet"
local dispatcher = require "net.dispatcher"
local userdata = require "data.userdata"
local usermeta = require "config.usermeta"

local session = nil
-- 网络消息分发器
local net_dispatcher = nil
local datameta = nil      -- 用户数据

local CMD = {}
local SOCKET = {}

skynet.register_protocol {
	name 	= "client",
	id 		= skynet.PTYPE_CLIENT,
	pack 	= skynet.pack,
	unpack 	= skynet.unpack,
}

local function unload()
	if datameta then
		local player = datameta:get("Player")
		if player then
			skynet.call(GLOBAL.SERVICE_NAME.USERCENTERD, "lua", "unload", player.uid)
		end
	end
end

function CMD.connect(source, fd, ip)
	if net_dispatcher then
		net_dispatcher:initialize()
	else
		net_dispatcher = dispatcher.new()
	end

	session = {}
	session.fd = fd
	datameta = userdata.new("w")
	datameta:register(usermeta)

	session.data = datameta

	skynet.send(source, "lua", "accept", fd)
end

function CMD.disconnect(source)
	unload()
	if session then
		skynet.send(source, "lua", "kick", session.fd)
	end
end

function CMD.message(source, msg, sz)
  if session then
	  	local msg_data = skynet.unpack(msg, sz)
        net_dispatcher:message_dispatch(session, msg_data)
  end
end

function CMD.load_data(source, name, data)
	local retval = datameta:init(name, data)
	if not retval then
		ERROR("usermeta:init(name = %s) failed!!!", name)
	end

	local result = retval:copy()

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
			return safe_handler(fn, source, ...)
		else
			return safe_handler(command_handler, source, cmd, ...)
		end
	end)

	--skynet.dispatch("client", function(session, source, cmd, ...)
	--	skynet.error("agent---client--"..cmd)
	--	local safe_handler = SAFE_HANDLER(session)
	--	local fn = SOCKET[cmd]
	--	if fn then
	--		return safe_handler(fn, source, ...)
	--	end
	--end)
end)
