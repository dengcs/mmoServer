local skynet = require "skynet"
require "skynet.manager"

local socket = require "skynet.socket"
local sockethelper = require "http.sockethelper"
local httpd = require "http.httpd"
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

HTTP服务注册句柄

]]

local service = {}

local function response(fd, ...)
    local ok, err = httpd.write_response(sockethelper.writefunc(fd), ...)
    if not ok then
        -- if err == sockethelper.socket_error, that means socket closed.
        LOG_ERROR("http: response: (%d) %s", fd, err)
    end
end

local function do_request(fd, cb)
    socket.start(fd)
    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(fd), 8192)
    if code then
        if code ~= 200 then
            response(fd, code)
        else
            local __response = function (code, ...)
                response(fd, code, ...)
            end
            cb(__response, url, method, header, body)
        end
    else
        if url == sockethelper.socket_error then
            LOG_ERROR("http: request: web socket closed")
        else
            LOG_ERROR("http: request: %s", tostring(url))
        end
    end
    socket.close(fd)
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

        return 0
    end

    function CMD.stop()
        if handler.stop_handler then
            handler.stop_handler()
        end

        return 0
    end

    function CMD.collect()
        AUTO_GC()
    end

    function CMD.request(_, fd)
        do_request(fd, handler.message_handler)
    end

    function CMD.schedule(_, func, interval, loop, args)
        return scheduler.schedule(func, interval, loop, args)
    end

    function CMD.unschedule(_, session)
        scheduler.unschedule(session)
    end
    
    function CMD.unschedule_all()
        scheduler.unschedule_all()
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

local function launch_master(conf)
    assert(conf.message_handler)
    assert(conf.command_handler)

    local listenfd   -- listen socket
    local CMD = {}

    local instance = conf.instance or 4
    assert(instance > 0)

    local slave = {}
    local balance = 1

    local handler = {
        init_handler    = conf.init_handler,
        exit_handler    = conf.exit_handler,
        start_handler   = conf.start_handler,
        stop_handler    = conf.stop_handler,
        message_handler = conf.message_handler,
        command_handler = conf.command_handler,
    }

    -- 服务初始逻辑
    function CMD.init(_, conf)
        -- 监听服务端口
        assert(not listenfd)
        local address = conf.address or "0.0.0.0"
        local port = assert(conf.port)
        skynet.error(string.format("Listen on %s:%d", address, port))
        listenfd = socket.listen(address, port)

        -- 通知目标服务
        if handler.init_handler then
            handler.init_handler(conf)
        end

        -- 构建工作服务
        for i = 1, #slave do
            local s = slave[i]
            skynet.call(s, "lua", "init", conf)
        end

        -- 启动服务逻辑
        if IS_TRUE(conf.auto) then
            this.start(conf)
        end

        return 0
    end

    -- 服务退出逻辑
    function CMD.exit()
        -- 停止服务
        this.stop()
        -- 停止通知
        if handler.exit_handler then
            handler.exit_handler()
        end

        DO_FINISH()

        return 0
    end

    -- 服务启动逻辑
    function CMD.start(...)
        -- 连接处理
        assert(listenfd)
        socket.start(listenfd, function (fd, addr)
            if instance == 1 then
                LOG_DEBUG("remote %s connected, pass it to native proc", addr)
                do_request(fd, handler.message_handler)
            else
                LOG_DEBUG("remote %s connected, pass it to agent %08x", addr, slave[balance])
                skynet.send(slave[balance], "lua", "request", fd)
                balance = balance + 1
                if balance > #slave then
                    balance = 1
                end
            end
        end)

        -- 启动通知
        if handler.start_handler then
            return handler.start_handler(...)
        end

        -- 启动通知
        for i = 1, #slave do
            local s = slave[i]
            skynet.send(s, "lua", "start", ...)
        end

        DO_STARTUP()

        return 0
    end

    -- 服务停止逻辑
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

        -- assert(listenfd)
        socket.close(listenfd)
        listenfd = nil

        return 0
    end

    -- 垃圾回收通知
    function CMD.collect()
        for i = 1, #slave do
            local s = slave[i]
            skynet.send(s, "lua", "collect")
        end

        AUTO_GC()
    end

    function CMD.schedule(_, func, interval, loop, args)
        return scheduler.schedule(func, interval, loop, args)
    end

    function CMD.unschedule(_, session)
        scheduler.unschedule(session)
    end
    
    function CMD.unschedule_all()
        scheduler.unschedule_all()
    end

    COMMAND_REGISTER("lua", function(session, source, cmd, ...)
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
            local sr = skynet.newservice(SERVICE_NAME, conf.name, conf.instance)
            print("for instance = " .. i .. " the new service handler = " .. sr .. " with name = " .. SERVICE_NAME)
            table.insert(slave, sr)
        end
    end
end

function service.start(conf)
    local name = "." .. assert(conf.name or conf.servername)
    skynet.start(function()
        local master = skynet.localname(name)
        if master then
            print("http master = " .. master .. " is ok")
            launch_master = nil
            launch_slave(conf)
        else
            print("http master is failed "..name)
            launch_slave = nil
            skynet.register(name)
            launch_master(conf)
        end
    end)
end

return service
