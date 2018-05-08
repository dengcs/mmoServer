local skynet = require "skynet"
local wsservice = require "service_factory.wsservice"
local netpack = require "skynet.netpack"

local connection = {}	-- fd -> connection : { fd , client, agent , ip, mode }

local conf = {ip = "0.0.0.0", port = 8001}

local handler = {}

function handler.on_connect(ws)

    local agent = skynet.newservice("client/agentd")

    local c = {
      fd = ws.id,
      ws = ws,
      agent = agent
    }
    connection[c.fd] = c
    
    skynet.call(agent, "lua", "connect", c)
end

function handler.on_message(ws, message)
    local c = connection[ws.id]
    if c then
        skynet.call(c.agent, "lua", "message", message)
    end
end

function handler.on_disconnect(ws)
    local c = connection[ws.id]
    if c then
        skynet.call(c.agent, "lua", "disconnect")
        connection[ws.id] = nil
    end
end

function handler.configure()
    return conf
end

wsservice.start(handler)
