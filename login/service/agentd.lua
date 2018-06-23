local skynet = require "skynet"
local dispatcher = require "net.dispatcher"

local csession
-- 网络消息分发器
local net_dispatcher

local CMD = {}
local Handle = {}

function CMD.connect(c)
  csession = c
  net_dispatcher = dispatcher.new()
  net_dispatcher:register_handle()
end

function CMD.disconnect()
	skynet.exit()
end

function CMD.message(msg)
  if csession then
--      local code,result = skynet.call(GLOBAL.SERVICE_NAME.PBD,"lua","decode",msg)
--      code,result = skynet.call(GLOBAL.SERVICE_NAME.PBD,"lua","encode",1001,"AwesomeMessage",result.data,0)
--      skynet.send(GLOBAL.SERVICE_NAME.GATED,"lua","response",csession.fd,result)
        net_dispatcher:message_dispatch(csession, msg)
  end
end

function Handle.login()
end

function Handle.logout()
end

-- 内部命令转发
-- 1. 命令来源
-- 2. 命令名称
-- 3. 命令参数
local function command_handler(command, ...)
    local fn = assert(Handle[command])
    if fn then
       return fn(...)
    else   
       skynet.error("This function is not implemented.")
    end
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
	   skynet.error("dcs---cmd--"..cmd)
		 local fn = assert(CMD[cmd])
		 if fn then
       skynet.ret(skynet.pack(fn(...)))
		 else
		   skynet.ret(skynet.pack(command_handler(cmd, ...)))
		 end
	end)
end)
