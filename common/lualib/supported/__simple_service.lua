local skynet = require "skynet"

local multicast = require "skynet.multicast"
local sharedata = require "skynet.sharedata"

local scheduler = require "scheduler"

local table = table
local string = string
local assert = assert

setmetatable(_G, {
    __newindex = function (_, k)
        error("Attempt to write undeclared variable " .. k)
    end,
    __index = function (_, k)
        error("Attempt to read undeclared variable " .. k)
    end,
})

--[[

注册服务属性的格式列表：

    ● 服务对外唯一注册别名：
      name = service_name

    ● 服务集群网络下的主机名称：
      master_name = "xxx"

    ● 服务注册的主题模式类型（终端模式、广播模式、自定义模式…）：
      proto = service_type

    ● 服务依赖模块文件列表：
      require = { service_name }

    ● 服务垃圾回收开启状态标识：
      collect = "true"

    ● 服务启动前初始化接口函数：
      init = function() end

    ● 服务内部派发的命令函数接口列表：
      CMD = { function() end, function() end }

    ● 服务构建接口回调句柄：
      init_handler = function() end

    ● 服务退出接口回调句柄：
      exit_handler = function() end

    ● 服务启动接口回调句柄：
      start_handler = function() end

    ● 服务停止接口回调句柄：
      stop_handler = function() end

    ● 用户加入当前服务接口回调句柄：
      join_handler = function() end

    ● 用户退出当前服务接口回调句柄：
      leave_handler = function() end

    ● 群组过滤广播发送接口回调句柄：
      push_handler = function() end

    ● 广播群发接口回调句柄：
      publish_handler = function() end

注意，此服务是基于已分解后的参数列表进行支撑处理，并默认提供如下接口：
1）共享数据接口支持，对外自动绑定共享数据模块；
2）用户管理接口支持，提供用户加入、离开相关回调；
3）多种广播接口支持，并向上提供校验功能；

]]

local service = {}

local handler_deps = {}

local __name
local __conf
local __master
local __proto
local __channel

local user_length = 0
local user_online = {}


-- 自带在线角色列表（调用角色接口）
function service.user_call(uid, cmd, ...)
    local u = user_online[uid]
    if u then
        return skynet.call(u.agent, "lua", cmd, ...)
    else
        ERROR(ENODATA, "call: %s: user (%s) not found", tostring(cmd), tostring(uid))
    end
end

-- 自带在线角色列表（触发角色通知）
function service.user_send(uid, cmd, ...)
    local u = user_online[uid]
    if u then
        skynet.send(u.agent, "lua", cmd, ...)
    else
        ERROR(ENODATA, "send: %s: user (%s) not found", tostring(cmd), tostring(uid))
    end
end

-- 返回在线角色列表
function service.users()
    return user_online
end

-- 判断角色是否在线
function service.is_user_online(uid)
    return (nil ~= user_online[uid])
end

local function prototype_name()
    if __proto == GLOBAL.PROTO_TYPE.TERMINAL then
        return GLOBAL.PROTO_NAME.TERMINAL
    elseif __proto == GLOBAL.PROTO_TYPE.MULTICAST then
        return GLOBAL.PROTO_NAME.MULTICAST
    elseif __proto == GLOBAL.PROTO_TYPE.USERINTER then
        return GLOBAL.PROTO_NAME.USERINTER
    else
        return GLOBAL.PROTO_NAME.UNKNOWN
    end
end

local builder = {}

function builder.init_terminal()
    __channel = skynet.self()
end

function builder.exit_terminal()
    __channel = nil
end

function builder.init_multicast()
    __channel = multicast.new()
end

function builder.exit_multicast()
    __channel = nil
end

function builder.init_userinter()
    __channel = skynet.self()
end

function builder.exit_userinter()
    __channel = nil
end

local function userid_list()
    local t = {}
    for k, _ in pairs(user_online) do
        table.insert(t, k)
    end
    return t
end

-- 返回服务类型（终端，广播，...）
function service.prototype()
    return __proto
end

-- ？？
function service.channel()
    if __proto == GLOBAL.PROTO_TYPE.TERMINAL then
        return __channel
    elseif __proto == GLOBAL.PROTO_TYPE.MULTICAST then
        return __channel.channel
    elseif __proto == GLOBAL.PROTO_TYPE.USERINTER then
        return __channel
    else
        ERROR(EINVAL, "channel: %s: unknown service prototype", tostring(__proto))
    end
end

-- 服务启动入口
-- 1. 服务模块
function service.register(conf)

    assert(conf.CMD)

    local CMD = {}

    -- 服务模块事件回调接口（处理服务固定事件"初始，退出，启动，停止，关联角色，取消关联，..."）
    local handler = {
        init_handler    = conf.init_handler,     -- assert(conf.init_handler)
        exit_handler    = conf.exit_handler,     -- assert(conf.exit_handler)
        start_handler   = conf.start_handler,    -- assert(conf.start_handler)
        stop_handler    = conf.stop_handler,     -- assert(conf.stop_handler)
        join_handler    = conf.join_handler,     -- assert(conf.join_handler)
        leave_handler   = conf.leave_handler,    -- assert(conf.leave_handler)
        push_handler    = conf.push_handler,     -- assert(conf.push_handler)
        publish_handler = conf.publish_handler,  -- assert(conf.publish_handler)
    }

    -- 服务初始化操作（为什么不可以自动执行呢？？因为初始配置的原因吗？？）
    -- 1. 消息来源
    -- 2. 初始配置
    function CMD.init(_, conf)
        __name   = conf.name
        __conf   = conf
        __master = conf.master or GLOBAL.MASTER_TYPE.UNKNOWN
        __proto  = conf.proto  or GLOBAL.PROTO_TYPE.UNKNOWN

        local proto_name = prototype_name()
        local f = builder["init_" .. proto_name]
        if f then
            f()
        else
            -- ERROR(EINVAL, "channel: %s: unknown service prototype", tostring(__proto))
        end

        -- 通知业务层服务初始化
        if handler.init_handler then
            handler.init_handler(conf)
        end

        -- 自动执行启动操作
        if IS_TRUE(conf.auto) then
            this.start(conf)
        end

        return 0
    end

    -- 服务退出操作（服务退出逻辑通过包装'dispatch'实现，指定调用完毕后，通过判断状态实现服务释放）
    function CMD.exit()
        -- 尝试调用服务退出逻辑
        for _, v in pairs(__conf.exit or {}) do
            skynet.call(skynet.self(), "lua", v.func, v.args)
        end

        this.stop()

        local proto_name = prototype_name()
        local f = builder["exit_" .. proto_name]
        if f then
            f()
        else
            -- ERROR(EINVAL, "channel: %s: unknown service prototype", tostring(__proto))
        end

        if handler.exit_handler then
            handler.exit_handler()
        end

        local uids = userid_list()
        for _, v in pairs(uids) do
            local r = CMD.leave(v)
            if r > 0 then
                LOG_WARN("exit: %s: user %s leaved failed", __name, tostring(v))
            end
        end

        DO_FINISH()

        return 0
    end

    function CMD.start(...)
        if handler.start_handler then
            handler.start_handler(...)
        end

        DO_STARTUP()

        return 0
    end

    function CMD.stop()
        if not IS_RUNNING() then
            return 0
        end

        DO_PAUSE()

        if handler.stop_handler then
            handler.stop_handler()
        end

        return 0
    end

    function CMD.collect()
        AUTO_GC()
    end

    -- 用户与服务绑定（为什么要实现这个逻辑呢？业务层自己考虑实现不是更好吗）
    -- 1. 命令来源
    -- 2. 用户编号
    -- 3. 用户句柄
    -- 4. 回调方法
    -- 5. 回调参数？？
    function CMD.join(_, uid, agent, cb, ...)
        assert(not user_online[uid], string.format("join: cannot create user '%s': user exists", uid))
        local u = {
            agent = agent,
            cb = cb,
        }
        user_online[uid] = u
        user_length = user_length + 1

        local m = prototype_name()
        local c = service.channel()
        skynet.call(agent, "lua", "register", m, __name, c, __master, cb)

        if handler.join_handler then
            handler.join_handler(uid, agent, cb, ...)
        end

        return 0
    end

    function CMD.leave(_, uid, ...)
        assert(user_length > 0, "")
        local m = prototype_name()
        local u = user_online[uid]
        if u ~= nil then
            skynet.send(u.agent, "lua", "unregister", m, __name)
            user_online[uid] = nil
            user_length = user_length - 1
        end
        if handler.leave_handler then
            handler.leave_handler(uid, ...)
        end
        return 0
    end

    -- 批量的通知关联到服务的在线用户
    function CMD.push(_, grp, ...)
        for _, v in pairs(grp) do
            local u = user_online[v]
            if u then
                skynet.send(u.agent, "lua", u.cb, ...)
            else
                LOG_WARN("could not found user %d in this service.", tostring(v))
            end
        end

        if handler.push_handler then
            handler.push_handler(grp, ...)
        end
    end

    local function do_user_publish(...)
        for uid, u in pairs(user_online) do
            skynet.send(u.agent, "lua", u.cb, ...)
        end
    end

    function CMD.publish(_, ...)
        if __proto == GLOBAL.PROTO_TYPE.TERMINAL then
            LOG_ERROR("cannot publish any infos for terminal type.")
        elseif __proto == GLOBAL.PROTO_TYPE.MULTICAST then
            assert(__channel, "multicast instance must be non-null")
            __channel:publish(...)
        elseif __proto == GLOBAL.PROTO_TYPE.USERINTER then
            do_user_publish(...)
        else
            ERROR(EINVAL, "channel: %s: unknown service prototype", tostring(__proto))
        end

        if handler.publish_handler then
            handler.publish_handler(...)
        end
    end

    -- 定时器(主要是使用了'skynet.timeout'方法)
    function CMD.schedule(_, func, interval, loop, args)
        return scheduler.schedule(func, interval, loop, args)
    end

    function CMD.unschedule(_, session)
        scheduler.unschedule(session)
    end

    function CMD.unschedule_all()
        scheduler.unschedule_all()
    end

    local function do_command(source, cmd, ...)
        local f = conf.CMD[cmd]
        if f then
            return f(...)
        else
            ERROR(EFAULT, "call: %s: command not found", tostring(cmd))
        end
    end

    -- 下面逻辑是否多余呢， 完全可以在业务层直接写上
    -- 如果业务层无法实现， 这里多半也是出现逻辑错误
    if conf.init then
        local f = conf.init
        skynet.init(f)
    end


    skynet.start(function()
        -- 确保依赖服务已经存在
        -- 问题来了
        -- 依赖服务构造完成后，需要初始化或者启动过程
        -- 所以最好的办法仍是通过配置指定服务启动过程
        if conf.require then
            local s = conf.require
            for _, v in pairs(s) do
                handler_deps[v] = skynet.uniqueservice(v)
            end
        end

        -- 命令转发逻辑
        COMMAND_REGISTER("lua", function(session, source, cmd, ...)
            local safe_handler = SAFE_HANDLER(session)
            local f = CMD[cmd]
            if f then
                return safe_handler(f, source, ...)
            else
                return safe_handler(do_command, source, cmd, ...)
            end
        end)

        --[[
        if conf.name and IS_TRUE(conf.unique) == false then
            skynet.register(conf.name)
        end
        ]]
    end)
end

return service
