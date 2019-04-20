---------------------------------------------------------------------
--- 用户管理服务（因为共享内存的关系，仅能管理所在节点用户）
---------------------------------------------------------------------
local service   = require "factory.service"
local skynet    = require "skynet_ex"
local userdata  = require "data.userdata"
local models    = require "config.models"
local dbproxy   = require "dbproxy"

---------------------------------------------------------------------
--- 内部变量/内部逻辑
---------------------------------------------------------------------

-- 在线用户列表
local onlines = {}

-- 保存角色数据
-- 1. 角色编号
-- 2. 角色信息
local function save(pid, user)
    for name, c in pairs(user.configure) do
        local data = user:get(name)
        if data:update() then
            dbproxy.set(c.mode,pid,data.__data)
        end
    end
end

-- 构造'userdata'只读实例
-- 1. 用户编号
-- 2. 配置信息
local function ucreate()
    local user = userdata.new("r")
    if models then
        user:register(models)
    end
    return user
end

---------------------------------------------------------------------
--- 服务导出接口
---------------------------------------------------------------------
local COMMAND = {}

-- 加载角色数据（只读，通过'sharedmap'与'agent'共享）
-- 1. 命令来源
-- 2. 角色编号
-- 3. 配置信息
function COMMAND.load(source, pid)
    -- 防止重复加载
    if onlines[pid] then
        ERROR("usercenterd : user[%s] already exists!!!", pid)
    end
    -- 加载角色数据
    local user = ucreate()
    for name, c in pairs(user.configure) do
        -- 加载角色组件数据
        -- name : 组件名称
        -- c    : 组件描述        
        local retval = dbproxy.get(c.mode, pid)
        
        local ok, objcpy = skynet.call(source, "lua", "load_data", name, retval)
        if ok ~= 0 and not objcpy then
            ERROR("usercenterd : component[%s] bind failed!!!", name)
        end
        user:init(name, objcpy)
    end
    -- 记录在线角色
    onlines[pid] =
    {
        agent = source,
        user  = user,
    }
    return 0
end

-- 释放在线角色
-- 1. 命令来源
-- 2. 角色编号
function COMMAND.unload(source, pid)
    local u = onlines[pid]
    if u then
        save(pid, u.user)
        u.user:cleanup_all()
        onlines[pid] = nil
    else
        ERROR("usercenterd : user[%s] not found!!!", pid)
    end
    return 0
end

-- 获取角色句柄
-- 1. 命令来源
-- 2. 角色编号
function COMMAND.useragent(source, pid)
    local u = onlines[pid]
    if u then
        return u.agent
    else
        return nil
    end
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
        local ok, retval = skynet.call(u.agent, "lua", cmd, ...)
        if ok ~= 0 then
            ERROR("usercenterd : command[%s] failed!!!", cmd)
        end
        return retval
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

-- 服务启动通知
function server.start_handler()
    -- 启动定时任务
    local interval = 5 * 60
    this.schedule(function()
        for pid, u in pairs(onlines) do
            save(pid, u.user)
        end
    end, interval, SCHEDULER_FOREVER)
end

-- 服务停止通知
function server.stop_handler()
    for pid, u in pairs(onlines) do
        save(pid, u.user)
    end
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
