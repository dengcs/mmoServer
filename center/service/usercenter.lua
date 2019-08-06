---------------------------------------------------------------------
--- 用户管理服务（因为共享内存的关系，仅能管理所在节点用户）
---------------------------------------------------------------------
local service   = require "factory.service"
local skynet    = require "skynet"

---------------------------------------------------------------------
--- 内部变量/内部逻辑
---------------------------------------------------------------------

-- 在线用户列表
local onlines = {}

---------------------------------------------------------------------
--- 服务导出接口
---------------------------------------------------------------------
local COMMAND = {}

-- 加载角色数据（只读，通过'sharedmap'与'agent'共享）
-- 1. 命令来源
-- 2. 角色编号
-- 3. 配置信息
function COMMAND.load(source, pid)
    -- 重复登陆需要踢下线
    local u = onlines[pid]
    if u then
        u.agent = source
        return 0
    end

    -- 记录在线角色
    onlines[pid] =
    {
        agent = source,
    }
    return 0
end

-- 释放在线角色
-- 1. 命令来源
-- 2. 角色编号
function COMMAND.unload(source, pid)
    local u = onlines[pid]
    if u then
        onlines[pid] = nil
    else
        ERROR("usercenterd : user[%s] not found!!!", pid)
    end
    return 0
end

-- 发送消息到指定角色
-- 1. 消息来源
-- 2. 角色编号
-- 3. 消息类型
-- 4. 消息内容
function COMMAND.usersend(source, pid, cmd, ...)
    local u = onlines[pid]
    if u then
        skynet.send(u.agent, "lua", cmd, ...)
    end
end

-- 调用指定角色逻辑
-- 1. 消息来源
-- 2. 角色编号
-- 3. 命令类型
-- 4. 命令内容
function COMMAND.usercall(source, pid, cmd, ...)
    local u = onlines[pid]
    if u then
        local ok, result = skynet.call(u.agent, "lua", cmd, ...)
        if ok ~= 0 then
            ERROR("usercenterd : command[%s] failed!!!", cmd)
        end
        return result
    end
end

-- 在线消息广播
-- 1. 指令来源
-- 2. 消息类型
-- 3. 消息内容
function COMMAND.broadcast(source, cmd, ...)
    for _, u in pairs(onlines or {}) do
        skynet.send(u.agent, "lua", cmd, ...)
    end
end

---------------------------------------------------------------------
--- 服务事件回调（底层事件通知）
---------------------------------------------------------------------
local server = {}

-- 服务开启通知
-- 1. 构造参数
function server.init_handler(arguments)
end

-- 服务退出通知
function server.exit_handler()
end

-- 内部命令分发
-- 1. 命令来源
-- 2. 命令名称
-- 3. 命令参数
function server.command_handler(source, cmd, ...)
    local fn = COMMAND[cmd]
    if fn then
        return fn(source, ...)
    else
        ERROR("command[%s] not found!!!", cmd)
    end
end

-- 启动用户管理服务
service.start(server)
