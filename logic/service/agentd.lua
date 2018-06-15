local skynet = require "skynet"
local dispatcher = require "net.dispatcher"
local userdata = require "data.userdata"
local usermeta = require "config.usermeta"

local csession
-- 网络消息分发器
local net_dispatcher
local playerdata      -- 用户数据

local CMD = {}
local Handle = {}

function CMD.connect(c)
  csession = c
  net_dispatcher = dispatcher.new()
  net_dispatcher:register_handle()
  
  playerdata = userdata.new("w")
  playerdata:register(usermeta)
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

function Handle.initdata(name, data)    
    local retval = playerdata:init(name, data)
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
		 local fn = CMD[cmd]
		 if fn then
       skynet.ret(skynet.pack(fn(...)))
		 else
		   skynet.ret(skynet.pack(command_handler(cmd, ...)))
		 end
	end)
end)
