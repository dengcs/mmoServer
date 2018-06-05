local skynet = require "skynet"
local wsservice = require "service_factory.wsservice"

local connection = {}

local ip,port = ...

local CMD = {}
local handler = {}

function handler.on_open(fd)
    local agent = skynet.newservice("client/agentd")
    
    local c = {
      fd = fd,
      agent = agent
    }
    
    connection[fd] = c    
end

function handler.on_close(fd)
    local c = connection[fd]
    if c then
        skynet.send(c.agent, "lua", "disconnect")
        connection[fd] = nil
    end
end

function handler.on_connect(ws)
    local c = connection[ws.id]
    
    if c then
        skynet.call(c.agent, "lua", "connect", c)
    end
end

function handler.on_message(ws, message)
    local c = connection[ws.id]
    if c then
        skynet.send(c.agent, "lua", "message", message)
    end
end

function handler.on_disconnect(ws)
    local c = connection[ws.id]
    if c then
        skynet.send(c.agent, "lua", "disconnect")
        connection[ws.id] = nil
    end
end

function handler.configure()
    return {ip=ip,port=port}
end

function handler.command(cmd,...)
    local fn = CMD[cmd]
    if fn then
      fn(...)
    end
end

function CMD.test()
  
end

wsservice.start(handler)
