---------------------------------------------------------------------
--- 聊天系统服务
---------------------------------------------------------------------
local service   = require "factory.service"
local skynet    = require "skynet"
local social    = require "social"

---------------------------------------------------------------------
--- 内部变量/内部逻辑
---------------------------------------------------------------------

local function notice(pid, data)
    this.usersend(pid, "chat_msg_notice", data)
end

local function broadcast(data)
    this.broadcast("chat_msg_notice", data)
end

local function load_send_info(pid, data)
    local userData = social.get_user_data(pid)
    if userData and data then
        data.send_pid       = pid
        data.send_name      = userData.nickname
        data.send_level     = userData.level
        data.send_portrait  = userData.portrait
        data.send_time      = this.time()
    end
end

---------------------------------------------------------------------
--- 服务导出业务接口
---------------------------------------------------------------------
local command = {}

function command.send_msg(params)
    local ret = 0


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




