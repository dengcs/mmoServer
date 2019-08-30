---------------------------------------------------------------------
--- 服务框架配件模块
---------------------------------------------------------------------
local skynet    = require "skynet"
local scheduler = require "scheduler"

---------------------------------------------------------------------
--- 服务框架相关变量
---------------------------------------------------------------------
MILLISECOND_UNIT        = 100
SCHEDULER_FOREVER 		= -1

---------------------------------------------------------------------
--- 服务框架调用方法
---------------------------------------------------------------------
local function __DO_COMMAND(f, ...)
    local ok = 0
    local result = nil

    if IS_FUNCTION(f) then
        result = f(...)
    else
        ok = EPERM
    end

    return table.pack(ok, result)
end

local function __SAFE_SEND(f, ...)
    if IS_FUNCTION(f) then
        f(...)
    end

    skynet.ret()
end

local function __SAFE_CALL(f, ...)
    local ok = 0
    local result = nil

    if IS_FUNCTION(f) then
        result = f(...)
    else
        ok = EPERM
    end

    return skynet.retpack(ok, result)
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
    return skynet.call(GLOBAL.SERVICE_NAME.USERCENTER, "lua", "usercall", pid, command, ...)
end

function this.usersend(pid, command, ...)
    return skynet.send(GLOBAL.SERVICE_NAME.USERCENTER, "lua", "usersend", pid, command, ...)
end

function this.broadcast(command, ...)
    return skynet.send(GLOBAL.SERVICE_NAME.USERCENTER, "lua", "broadcast", command, ...)
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
