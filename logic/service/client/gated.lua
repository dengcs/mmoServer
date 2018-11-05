local skynet 		= require "skynet"
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
	    
	    skynet.send(agent, "lua", "connect", session)
	end
	
	print("open_number:"..open_number)
end

function handler.on_disconnect(fd)
    print(string.format("%d disconnect", fd))
    
    local session = sessions[fd]
    if session then
        skynet.send(session.agent, "lua", "disconnect")        
        sessions[fd] = nil
    end
end

function handler.on_open(ws)
    print(string.format("%d::open", ws.id))
    
    local session = sessions[ws.id]
    
    if session then
        skynet.call(session.agent, "lua", "open")
	    session.ws = ws
	    open_number = open_number + 1
    end    
end

function handler.on_message(ws, message)
    print(string.format("%d receive:%s", ws.id, message))
    
    local session = sessions[ws.id]
    if session then
        skynet.send(session.agent, "lua", "message", message)
    end
end

function handler.on_close(ws, code, reason)
    print(string.format("%d close:%s  %s", ws.id, code, reason))
    
    local session = sessions[ws.id]
    if session then
        skynet.send(session.agent, "lua", "close")        
        sessions[ws.id] = nil
        open_number = open_number - 1
    end
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

function CMD.push_agent(agent)
	return agent_mgr:push(agent)
end

function handler.command(cmd,...)
    local fn = CMD[cmd]
    if fn then
      return fn(...)
    end
end

wsservice.start(handler)