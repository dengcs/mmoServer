---------------------------------------------------------------------
--- 系统服务框架（通过指定一组回调接口，提供规范服务操作模式）
--- 1. on_init    : 服务构建回调接口
--- 2. on_exit    : 服务退出回调接口
--- 3. on_start   : 服务启动回调接口
--- 4. on_stop    : 服务停止回调接口
--- 5. on_command : 业务指令回调接口
--- 6. on_collect : 垃圾回收回调接口
---------------------------------------------------------------------
local skynet = require "skynet"
local scheduler = require "scheduler"

-- 系统服务框架
local service = {}

-- 服务启动入口
-- 1. 业务模块
function service.start(module)
    -- 业务回调接口
    assert(module.command_handler)
    local handler = 
    {
        on_init    = module.init_handler,
        on_exit    = module.exit_handler,
        on_start   = module.start_handler,
        on_stop    = module.stop_handler,
        on_command = module.command_handler,
        on_collect = module.collect_handler,
    }

    -- 基础服务接口
    local command = {}

    -- 服务构建逻辑
    -- 1. 指令来源
    -- 2. 构建参数
    function command.init(source, config)
        if handler.on_init then
            handler.on_init(config)
        end
        DO_READY()
        if IS_TRUE(config.auto) then
            this.start(config)
        end
    end

    -- 服务退出逻辑
    -- 1. 指令来源
    function command.exit(source)
        this.stop()
        if handler.on_exit then
            handler.on_exit()
        end
        DO_FINISH()
    end

    -- 服务启动逻辑
    -- 1. 指令来源
    -- 2. 启动参数
    function command.start(source, ...)
        if handler.on_start then
            handler.on_start(...)
        end
        DO_START()
    end

    -- 服务停止逻辑
    -- 1. 指令来源
    function command.stop(source)
        if IS_RUNNING() then
            DO_PAUSE()
            if handler.on_stop then
                handler.on_stop()
            end
        end
    end

    -- 强制垃圾回收
    function command.collect()
        if handler.on_collect then
            handler.on_collect()
        end
        collectgarbage("collect")
    end
    
    -- 定时器(主要是使用了'skynet.timeout'方法)
    function command.schedule(_, func, interval, loop, args)
        return scheduler.schedule(func, interval, loop, args)
    end

    function command.unschedule(_, session)
        scheduler.unschedule(session)
    end

    function command.unschedule_all()
        scheduler.unschedule_all()
    end

    -- 业务指令转发
    local function do_command(source, ...)
        if IS_RUNNING() then
            return handler.on_command(source, ...)
        else
            ERROR("service isn't running!!!")
        end
    end

    -- 启动目标服务
    skynet.start(function()
        SERVICE_COMMAND_REGISTER("lua", function(session, source, cmd, ...)
            local safe_handler = SAFE_HANDLER(session)
	        local f = command[cmd]
	        if f then
	            safe_handler(f, source, ...)
	        else
	            safe_handler(do_command, source, cmd, ...)
	        end
        end)
    end)
end

return service
