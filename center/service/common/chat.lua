---------------------------------------------------------------------
--- 聊天系统服务
---------------------------------------------------------------------
local service   = require "factory.service"
local skynet    = require "skynet"
local social    = require "social"

---------------------------------------------------------------------
--- 内部变量/内部逻辑
---------------------------------------------------------------------

local CHANNEL_TYPE =
{
    PRIVATE     = 1,    -- 私聊频道
    WORLD       = 2,    -- 世界频道
}

local function notice(pid, data)
    this.usersend(pid, "chat_msg_notice", data)
end

local function broadcast(data)
    this.broadcast("chat_msg_notice", data)
end

local function load_chat_info(params)
    local pid       = params.source
    local userData  = social.get_user_data(pid)
    if userData then
        local data = {}
        data.send_pid       = pid
        data.send_name      = userData.nickname
        data.send_level     = userData.level
        data.send_portrait  = userData.portrait
        data.send_time      = this.time()
        data.channel        = params.channel
        data.receive_pid    = params.receive_pid
        data.content        = params.content
        return data
    end
end

local channel = {}

function channel.new(type)
    local chan = { type = type}
    return setmetatable(chan, {__index = channel})
end

function channel:send(data)
    if self.type == CHANNEL_TYPE.PRIVATE then
        notice(data.receive_pid, data)
    elseif self.type == CHANNEL_TYPE.WORLD then
        broadcast(data)
    end
end

local channels =
{
    [CHANNEL_TYPE.PRIVATE]  = channel.new(CHANNEL_TYPE.PRIVATE),
    [CHANNEL_TYPE.WORLD]    = channel.new(CHANNEL_TYPE.WORLD),
}

---------------------------------------------------------------------
--- 服务导出业务接口
---------------------------------------------------------------------
local command = {}

function command.send_msg(params)
    local ret = 0

    local toChannel = channels[params.channel]
    if toChannel then
        local send_data = load_chat_info(params)
        if send_data then
            toChannel:send(send_data)
        end
    end

    return ret
end

---------------------------------------------------------------------
--- 服务事件回调
---------------------------------------------------------------------
local server = {}

-- 内部指令通知
-- 1. 指令来源
-- 2. 指令名称
-- 3. 执行参数
function server.command_handler(source, cmd, ...)
    local fn = command[cmd]
    if fn then
        return fn(...)
    else
        ERROR("social : command[%s] not found!!!", cmd)
    end
end

-- 启动服务
service.start(server)




