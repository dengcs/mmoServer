local skynet 		= require "skynet_ex"
local wsservice 	= require "factory.wsservice"
local agent_manager 	= require "agent_manager"

local sessions = {}

local ip,port = ...

local CMD = {}
local handler = {}

local open_number = 0

local agent_mgr = agent_manager.new()

function handler.on_connect(fd)
	local session = sessions[fd]
	if not session then
		local agent = agent_mgr:pop()
		if not agent then
			agent = skynet.newservice("agentd")
		end

	    local session = {
	      fd = fd,
	      agent = agent
	    }
	    
	    sessions[fd] = session
	    
	    skynet.call(agent, "lua", "connect")
	end
end

function handler.on_disconnect(fd)
    local session = sessions[fd]
    if session then
		local agent = session.agent

        skynet.send(agent, "lua", "disconnect")
        sessions[fd] = nil

		if not agent_mgr:push(agent) then
			skynet.kill(agent)
		end
    end
end

function handler.on_open(ws)
	local fd = ws.id
    local session = sessions[fd]
    
    if session then
		session.ws = ws
		skynet.send(session.agent, "lua", "open", fd)
		open_number = open_number + 1
    end
	skynet.error("open_number:"..open_number)
end

function handler.on_message(fd, message)
    local session = sessions[fd]
    if session then
        skynet.send(session.agent, "lua", "message", message)
    end
end

function handler.on_close(fd, code, reason)
    local session = sessions[fd]
    if session then
		local agent = session.agent

        skynet.send(agent, "lua", "close")
        sessions[fd] = nil
        open_number = open_number - 1

		if not agent_mgr:push(agent) then
			skynet.kill(agent)
		end
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