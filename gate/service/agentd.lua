local skynet = require "skynet"
local dispatcher = require "net.dispatcher"

local session = nil
-- 网络消息分发器
local net_dispatcher = nil

local CMD = {}

function CMD.connect()
	if net_dispatcher then
		net_dispatcher:initialize()
	else
		net_dispatcher = dispatcher.new()
	end
end

function CMD.disconnect()
end

function CMD.open(source, fd)
	session = {}
	session.fd = fd
end

function CMD.close()
end

function CMD.message(source, msg)
  if session then
  end
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
end)
