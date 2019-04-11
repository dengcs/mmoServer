local skynet 		= require "skynet_ex"
local wsservice 	= require "factory.wsservice"

local sessions = {}

local CMD = {}
local handler = {}

function handler.on_connect(ws)
	local fd = ws.id
	local session = sessions[fd]
	if not session then
		local session = { ws = ws }
		sessions[fd] = session
	else
		session.ws = ws
	end

	skynet.send(GLOBAL.SERVICE_NAME.RELAY, "lua", "transmit", fd, "connect")
end

function handler.on_disconnect(fd)
    local session = sessions[fd]
    if session then
        sessions[fd] = nil
    end

	skynet.send(GLOBAL.SERVICE_NAME.RELAY, "lua", "transmit", fd, "disconnect")
end

function handler.on_message(fd, message)
    local session = sessions[fd]
    if session then
		skynet.send(GLOBAL.SERVICE_NAME.RELAY, "lua", "forward", fd, message)
    end
end

-- 关闭客户端
function CMD.logout(fd)
  local session = sessions[fd]
  if session then
  	  local ws = session.ws
  	  if ws then
	      ws:close()
  	  end
  end
end

-- 返回消息到客户端
function CMD.response(fd,msg)
	local session = sessions[fd]
	if session then
  	  	local ws = session.ws
  	  	if ws then
	      	ws:send_binary(msg)
  	  	end
	end
end

function handler.command(cmd,...)
    local fn = CMD[cmd]
    if fn then
      	return fn(...)
    end
end

wsservice.start(handler)