local skynet = require "skynet"
require "skynet.manager"

local socketdriver = require "skynet.socketdriver"
local netpack = require "skynet.netpack"

local scheduler = require "scheduler"

local table  = table
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

SOCKET服务注册句柄

]]

local service = {}

local function do_accept(fd, msg, sz, cb)
    local data = netpack.tostring(msg, sz)
    return cb(fd, data)
end

local function do_response(fd, data)
    socketdriver.send(fd, netpack.pack(data))
    return 0
end

local function launch_slave(conf)
    local CMD = {}

    local handler = {
        init_handler    = conf.init_handler,
        exit_handler    = conf.exit_handler,
        start_handler   = conf.start_handler,
        stop_handler    = conf.stop_handler,
        message_handler = assert(conf.message_handler),
        command_handler = assert(conf.command_handler),
    }

    function CMD.init(_, conf)
        if handler.init_handler then
            handler.init_handler(conf)
        end

        return 0
    end

    function CMD.exit()
        if handler.exit_handler then
            handler.exit_handler()
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

    function CMD.request(_, fd, msg, sz)
        return do_accept(fd, msg, sz, handler.message_handler)
    end

    function CMD.response(_, fd, data)
        return do_response(fd, data)
    end

    function CMD.collect()
        AUTO_GC()
    end

    COMMAND_REGISTER("lua", function(session, source, cmd, ...)
        local safe_handler = SAFE_HANDLER(session)
        local f = CMD[cmd]
        if f then
            return safe_handler(f, source, ...)
        else
            return safe_handler(handler.command_handler, source, cmd, ...)
        end
    end)
end

--
-- 网络服务启动逻辑
--
local function launch_master(conf)
    assert(conf.connect_handler)
    assert(conf.message_handler)
    assert(conf.command_handler)

    local socket            -- listen socket
    local queue             -- message queue
    local maxclient         -- max client
    local nodelay = false
    local client_number = 0
    local connection = {}
    local CMD = {}

    local instance = conf.instance or 4
    assert(instance > 0)

    local slave = {}
    local balance = 1

    -- 业务层消息处理接口
    local handler = {
        init_handler        = conf.init_handler,
        exit_handler        = conf.exit_handler,
        start_handler       = conf.start_handler,
        stop_handler        = conf.stop_handler,
        connect_handler     = conf.connect_handler,
        disconnect_handler  = conf.disconnect_handler,
        error_handler       = conf.error_handler,
        warning_handler     = conf.warning_handler,
        message_handler     = conf.message_handler,
        command_handler     = conf.command_handler,
    }

    -- 网络服务开启逻辑
    function CMD.init(_, conf)
        -- 打开监听端口
        assert(not socket)
        local address = conf.address or "0.0.0.0"
        local port = assert(conf.port)
        maxclient = conf.maxclient or 1024
        LOG_INFO("Listen on %s:%d", address, port)
        socket = socketdriver.listen(address, port)
        -- 通知网络服务开启（业务逻辑）
        if handler.init_handler then
            handler.init_handler(conf)
        end
        -- 通知工作服务开启
        for i = 1, #slave do
            local s = slave[i]
            skynet.send(s, "lua", "init", conf)
        end
        -- 自动启动网络服务
        if IS_TRUE(conf.auto) then
            this.start(conf)
        end
        return 0
    end

    -- 网络服务退出逻辑
    function CMD.exit()
        this.stop()
        -- 通知网络服务退出（业务逻辑）
        if handler.exit_handler then
            handler.exit_handler()
        end
        DO_FINISH()
        return 0
    end

    -- 网络服务启动逻辑
    function CMD.start(...)
        socketdriver.start(socket)
        -- 通知网络服务启动（业务逻辑）
        if handler.start_handler then
            handler.start_handler(...)
        end
        -- 通知工作服务启动
        for i = 1, #slave do
            local s = slave[i]
            skynet.send(s, "lua", "start", ...)
        end
        DO_STARTUP()
        return 0
    end

    -- 网络服务停止逻辑
    function CMD.stop()
        if not IS_RUNNING() then
            return 0
        end
        DO_PAUSE()
        for i = 1, #slave do
            local s = slave[i]
            skynet.send(s, "lua", "stop")
        end
        if handler.stop_handler then
            handler.stop_handler()
        end
        -- assert(socket)
        socketdriver.close(socket)
        socket = nil
        return 0
    end

    -- 应答（推送数据到客户端）
    function CMD.response(_, fd, data)
        return do_response(fd, data)
    end

    -- 垃圾收集
    function CMD.collect()
        for i = 1, #slave do
            local s = slave[i]
            skynet.send(s, "lua", "collect")
        end
        AUTO_GC()
    end

    -- 设置定时任务
    function CMD.schedule(_, func, interval, loop, args)
        return scheduler.schedule(func, interval, loop, args)
    end

    -- 取消定时任务
    function CMD.unschedule(_, session)
        scheduler.unschedule(session)
    end

    -- 取消所有定时任务
    function CMD.unschedule_all()
        scheduler.unschedule_all()
    end

    -- 执行服务的启动逻辑（业务逻辑）
    if conf.init then
        local f = conf.init
        skynet.init(f)
    end

    -- 网络消息处理逻辑
    local MSG = {}

    -- 单个网络消息通知
    local function dispatch_msg(fd, msg, sz)
        if instance == 1 then
            -- 数据直接转发到业务逻辑
            do_accept(fd, msg, sz, handler.message_handler)
        else
            local ok, err = skynet.call(slave[balance], "lua", "request", fd, msg, sz)
            balance = balance + 1
            if balance > #slave then
                balance = 1
            end
            if not ok then
                skynet.error(string.format("invalid client (fd = %d) error = %s", fd, tostring(err)))
            end
        end
        -- 这里好奇怪？？？
        socketdriver.close(fd)    -- We haven't call socket.start, so use socket.close_fd rather than socket.close.
    end
    MSG.data = dispatch_msg

    -- 批量网络消息通知
    local function dispatch_queue()
        local fd, msg, sz = netpack.pop(queue)
        if fd then
            -- may dispatch even the handler.message blocked
            -- If the handler.message never block, the queue should be empty, so only fork once and then exit.
            skynet.fork(dispatch_queue)
            dispatch_msg(fd, msg, sz)
            for fd, msg, sz in netpack.pop, queue do
                dispatch_msg(fd, msg, sz)
            end
        end
    end
    MSG.more = dispatch_queue

    -- 网络连接通知
    function MSG.open(fd, msg)
        if client_number >= maxclient then
            socketdriver.close(fd)
            return
        end
        if nodelay then
            socketdriver.nodelay(fd)
        end
        connection[fd] = true
        client_number = client_number + 1
        socketdriver.start(fd)
        handler.connect_handler(fd, msg)
    end

    local function close_fd(fd)
        local c = connection[fd]
        if c ~= nil then
            connection[fd] = nil
            client_number = client_number - 1
        end
    end

    -- 连接断开通知
    function MSG.close(fd)
        if fd ~= socket then
            if handler.disconnect_handler then
                handler.disconnect_handler(fd)
            end
            close_fd(fd)
        else
            socket = nil
        end
    end

    -- 连接错误通知
    function MSG.error(fd, msg)
        if fd == socket then
            socketdriver.close(fd)
            skynet.error(msg)
        else
            if handler.error_handler then
                handler.error_handler(fd, msg)
            end
            close_fd(fd)
        end
    end

    function MSG.warning(fd, size)
        if handler.warning then
            handler.warning_handler(fd, size)
        end
    end

    -- 注册网络消息处理逻辑
    skynet.register_protocol {
        name = "socket",
        id = skynet.PTYPE_SOCKET,
        unpack = function (msg, sz)
            return netpack.filter(queue, msg, sz)
        end,
        dispatch = function (_, _, q, type, ...)
            queue = q
            if type then
                local f = MSG[type]
                f(...)
            end
        end
    }

    COMMAND_REGISTER("lua", function (session, source, cmd, ...)
        local safe_handler = SAFE_HANDLER(session)
        local f = CMD[cmd]
        if f then
            return safe_handler(f, source, ...)
        else
            return safe_handler(conf.command_handler, source, cmd, ...)
        end
    end)

    -- 若服务实例数为1，则直接则主服务线程中处理上行请求数据
    if instance > 1 then
        for i = 1, instance do
            local sr = skynet.newservice(SERVICE_NAME)
            print("for instance = " .. i .. " the new service handler = " .. sr .. " with name = " .. SERVICE_NAME)
            table.insert(slave, sr)
        end
    end
end

-- 启动网络服务
-- 1. 从代码看来，'slave'不是为了降低单节点流量瓶颈而是为了增加CPU使用量而设置的
-- 2. 仅仅支持一问一答的短连接
function service.start(conf)
    local name = assert(conf.name or conf.servername)
    skynet.start(function()
        -- 检查服务是否存在
        local master = skynet.localname(name)
        if master then
            -- 启动工作服务
            launch_master = nil
            launch_slave(conf)
        else
            -- 启动网络服务
            launch_slave = nil
            skynet.register(name)
            launch_master(conf)
        end
    end)
end

return service
