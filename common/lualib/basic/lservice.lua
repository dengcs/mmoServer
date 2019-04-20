---------------------------------------------------------------------
--- 服务框架配件模块
---------------------------------------------------------------------
local skynet    = require "skynet"
local scheduler = require "scheduler"

---------------------------------------------------------------------
--- 服务框架相关变量
---------------------------------------------------------------------

SCHEDULER_FOREVER 		= -1

---------------------------------------------------------------------
--- 服务框架调用方法
---------------------------------------------------------------------
local function __DO_COMMAND(f, ...)
    local ok, result = xpcall(f, function (message)
        skynet.error(debug.traceback())
        return message
    end, ...)
    if not ok then
        return table.pack(ok, result)
    end

    return table.pack(0, result)
end

local function __SAFE_SEND(f, ...)
    local ok, result = xpcall(f, function (message)
        skynet.error(debug.traceback())
        return message
    end, ...)
    if not ok then
        LOG_ERROR(result)
    end
end

local function __SAFE_CALL(f, ...)
    local ok, result = xpcall(f, function (message)
        LOG_ERROR(message)
        skynet.error(debug.traceback())
        return message
    end, ...)
    if not ok then
        return skynet.ret(skynet.pack(ok, result))
    end

    return skynet.ret(skynet.pack(0, result))
end

function SAFE_HANDLER(session)
    if not session then
        return __DO_COMMAND
    elseif session > 0 then
        return __SAFE_CALL
    else
        return __SAFE_SEND
    end
end

function AUTO_GC()
    collectgarbage("collect")
end


---------------------------------------------------------------------
--- 内置快速调用接口
---------------------------------------------------------------------
this = {}

function this.usercall(pid, command, ...)
    return skynet.call(GLOBAL.SERVICE_NAME.USERCENTERD, "lua", "usercall", pid, command, ...)
end

function this.usersend(pid, command, ...)
    return skynet.send(GLOBAL.SERVICE_NAME.USERCENTERD, "lua", "usersend", pid, command, ...)
end

function this.call(command, ...)
    return skynet.call(skynet.self(), "lua", command, ...)
end

function this.start(...)
    return skynet.call(skynet.self(), "lua", "start", ...)
end

function this.stop()
    return skynet.call(skynet.self(), "lua", "stop")
end

function this.schedule(func, interval, loop, args)
    return scheduler.schedule(func, interval, loop, args)
end

function this.unschedule(session)
    scheduler.unschedule(session)
end

function this.unschedule_all()
    scheduler.unschedule_all()
end

function this.time()
    return math.floor(skynet.time())
end
