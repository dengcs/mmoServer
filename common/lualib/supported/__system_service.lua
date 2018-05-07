local skynet = require "skynet"

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

服务注册句柄的格式列表：

● 服务构建回调接口：init_handler
● 服务退出回调接口：exit_handler
● 服务启动回调接口：start_handler
● 服务停止回调接口：stop_handler
● 服务指令回调接口：command_handler

注意，此服务是纯净的默认服务处理流程接口，对上层仅绑定一个命令回调接口，由上层自行解析处理。
若需要在服务中接入其它业务，需自行导入相关模块。

]]

local service = {}

local delegate = {}

function service.start(conf)
    assert(conf.command_handler)

    local CMD = {}

    local handler = {
        init_handler  = conf.init_handler,
        exit_handler  = conf.exit_handler,
        start_handler = conf.start_handler,
        stop_handler  = conf.stop_handler,
    }

    function CMD.init(_, conf)
        if handler.init_handler then
            handler.init_handler(conf)
        end

        -- 其实就这个东西（服务事件回调，通知业务层）
        if conf.delegate then
            delegate = require(conf.delegate)
        end

        if delegate.init_handler then
            delegate.init_handler()
        end

        if IS_TRUE(conf.auto) then
            this.start(conf)
        end

        return 0
    end

    function CMD.exit()
        this.stop()

        if delegate.exit_handler then
            delegate.exit_handler()
        end

        delegate = nil

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

        if delegate.start_handler then
            delegate.start_handler(...)
        end

        DO_STARTUP()

        return 0
    end


    function CMD.stop()
        if not IS_RUNNING() then
            return 0
        end

        DO_PAUSE()

        if delegate.stop_handler then
            delegate.stop_handler()
        end

        if handler.stop_handler then
            handler.stop_handler()
        end

        return 0
    end

    -- 垃圾回收
    function CMD.collect()
        AUTO_GC()
    end

    -- 设置定时器
    function CMD.schedule(_, func, interval, loop, args)
        return scheduler.schedule(func, interval, loop, args)
    end

    -- 取消指定定时器
    function CMD.unschedule(_, session)
        scheduler.unschedule(session)
    end
    
    -- 取消所有定时器
    function CMD.unschedule_all()
        scheduler.unschedule_all()
    end

    -- 启动依赖项
    if conf.init then
        local f = conf.init
        skynet.init(f)
    end

    -- 服务启动（设置消息转发逻辑）
    skynet.start(function ()
        COMMAND_REGISTER("lua", function (session, source, cmd, ...)
            local safe_handler = SAFE_HANDLER(session)
            local f = CMD[cmd]
            if f then
                return safe_handler(f, source, ...)
            else
                return safe_handler(conf.command_handler, source, cmd, ...)
            end
        end)
    end)
end

return service
