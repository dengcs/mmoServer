---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by dengcs.
--- DateTime: 2018/11/27 11:28
---
local skynet        = require "skynet"
local gateserver    = require "snax.gateserver"
local agent_pool    = require "agent_pool"

-- 协议注册(允许提交'client'类型消息)
skynet.register_protocol({
    name = "client",
    id   = skynet.PTYPE_CLIENT,
})

local str_unpack    = string.unpack
-- 无符号整型数据类型的长度
local fd_sz = string.pack(">J", 1):len()

local agent_pool_inst = agent_pool.new()

local connection = {}

local handler = {}

local function close_fd(fd)
    if connection[fd] then
        connection[fd] = nil
        gateserver.closeclient(fd)
    end
end

local function fork_msg(fd, msg)
    local clients = connection[fd]
    if clients then
        local fd_data = skynet.tostring(msg, fd_sz)
        if fd_data then
            local client_fd = str_unpack(">J", fd_data)
            local agent     = clients[client_fd]
            if not agent then
                agent = agent_pool_inst:pop()
                clients[client_fd] = agent
                skynet.call(agent, "lua", "connect", fd, client_fd)
                return
            end

            return agent
        end
    end
end

function handler.open()
    agent_pool_inst:init()
    skynet.error("agent_pool init finish")
end

function handler.connect(fd, addr)
    connection[fd] = {}
    gateserver.openclient(fd)
end

function handler.message(fd, msg, sz)
    local agent = fork_msg(fd, msg)
    if agent then
        skynet.rawsend(agent, "client", msg, sz)
    end
end

function handler.disconnect(fd)
    close_fd(fd)
end

function handler.error(fd, msg)
    close_fd(fd)
end

function handler.warning(fd, size)
end

local CMD = {}

function CMD.disconnect(fd, client_fd)
    local clients = connection[fd]
    if clients then
        clients[client_fd] = nil
    end
end

function handler.command(cmd, source, ...)
    local f = assert(CMD[cmd])
    return f(...)
end

gateserver.start(handler)