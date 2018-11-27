local skynet 		= require "skynet_ex"
local wsservice 	= require "factory.wsservice"

local sessions = {}

local ip,port = ...

local CMD = {}
local handler = {}

local open_number = 0

function handler.on_connect(fd)
	local session = sessions[fd]
	if not session then
	    local session = {
	      fd = fd,
	    }
	    
	    sessions[fd] = session
	end
end

function handler.on_disconnect(fd)
    local session = sessions[fd]
    if session then
        sessions[fd] = nil
    end
end

function handler.on_open(ws)
	local fd = ws.id
    local session = sessions[fd]
    
    if session then
		session.ws = ws
		open_number = open_number + 1
    end
	skynet.error("open_number:"..open_number)
end

function handler.on_message(fd, message)
    local session = sessions[fd]
    if session then
		skynet.send(GLOBAL.SERVICE_NAME.RELAY, "lua", "receive", fd, message)
    end
end

function handler.on_close(fd, code, reason)
    local session = sessions[fd]
    if session then
        sessions[fd] = nil
        open_number = open_number - 1
    end
	skynet.error("open_number:"..open_number)
end

function handler.configure()
    return {ip=ip,port=port}
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