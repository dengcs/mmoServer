local skynet = require "skynet"
local netpack = require "skynet.netpack"

local csession

local CMD = {}

function CMD.connect(c)
  csession = c
end

function CMD.disconnect()
	skynet.exit()
end

function CMD.message(msg)
  skynet.error("dcs--"..msg)
  csession.ms:send_text(msg .. " from server")
  
  if msg=="bye" then
    skynet.send(GLOBAL.SERVICE_NAME.GATED,"lua","closeclient")
  end
end

-- 内部命令转发
-- 1. 命令来源
-- 2. 命令名称
-- 3. 命令参数
local function command_handler(source, command, ...)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, command, ...)
	   local safe_handler = SAFE_HANDLER(session)
		 local fn = CMD[command]
		 if fn then
		    return safe_handler(fn, source, ...)
		 else
		    return safe_handler(command_handler, source, command, ...)
		 end
	end)
end)
