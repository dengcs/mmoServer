local skynet = require "skynet"

local table = table
local string = string
local assert = assert

_NOVA = {}

_NOVA.SERVICE_INSTANCE = nil

_NOVA.COMMAND_DISPATCH = {
    SEND = function (...) LOG_WARN("Command Dispatch Not Implemented.") end,
    CALL = function (...) LOG_WARN("Command Dispatch Not Implemented.") end,
}

-- 底层事件通知接口
_NOVA.TRIGGER_DISPATCH = 
{
    CALL = function (...) LOG_WARN("Trigger Dispatch Not Implemented.") end,
}


local protocol = {}

-- 标识当前服务是否已处于终结状态
local is_finished = false

-- 标识当前服务是否正处于运行状态
local is_running = false

function SERVICE_REGISTER(name)
    local instance = require(name)
    _NOVA.SERVICE_INSTANCE = assert(instance)
    return instance
end

function COMMAND_REGISTER(typename, func)
    assert(func)
    assert(not protocol[typename])

    local function __dispatcher(session, source, ...)
        if is_finished == true then
            return INTERRUPT_SERVICE_RESPONSE(session)
        end

        local result = func(session, source, ...)

        if is_finished == true then
            skynet.exit()
        end

        return RESPONSE_SERVICE_RESULT(session, result)
    end

    protocol[typename] = __dispatcher

    local r = skynet.dispatch(typename, __dispatcher)
    if r then
        LOG_ERROR("nova: %s: dispatch is already registed", typename)
    end

    local __COMMAND_SEND = function (typename, cmd, ...)
        local f = protocol[typename]
        f(nil, skynet.self(), cmd, ...)
    end

    local __COMMAND_CALL = function (typename, cmd, ...)
        local f = protocol[typename]
        return f(nil, skynet.self(), cmd, ...)
    end

    local c = {
        SEND = __COMMAND_SEND,
        CALL = __COMMAND_CALL,
    }

    _NOVA.COMMAND_DISPATCH = c
end

-- 注册底层事件通知接口
function TRIGGER_REGISTER(fn)
    assert(fn)
    -- 注册通知接口
    local c = 
    {
        CALL = function(...)
            if not is_finished then
                fn(...)
            end
        end,
    }
    _NOVA.TRIGGER_DISPATCH = c
end

function DO_FINISH()
    assert(not is_finished)

    is_finished = true
end

function DO_STARTUP()
    is_running = true
end

function DO_PAUSE()
    is_running = false
end

function IS_RUNNING()
    return is_running
end

--[[

提供一些服务内置的常规函数接口，供用户快速调用。
接口使用方式参考面向对象语言结构，将整个服务作为一个对象实体，而此‘this’对象作为当前服务部分接口的一个封装‘伪对象’

]]

this = {}

this.instance = function ()
    return _NOVA.SERVICE_INSTANCE
end

this.send = function (cmd, ...)
    _NOVA.COMMAND_DISPATCH.SEND("lua", cmd, ...)
end

this.call = function (cmd, ...)
    return _NOVA.COMMAND_DISPATCH.CALL("lua", cmd, ...)
end

this.start = function ()
    return _NOVA.COMMAND_DISPATCH.CALL("lua", "start")
end

this.stop = function ()
    return _NOVA.COMMAND_DISPATCH.CALL("lua", "stop")
end

this.collect = function ()
    _NOVA.COMMAND_DISPATCH.SEND("lua", "collect")
end

this.join = function (...)
    return _NOVA.COMMAND_DISPATCH.CALL("lua", "join", ...)
end

this.leave = function (...)
    return _NOVA.COMMAND_DISPATCH.CALL("lua", "leave", ...)
end

this.push = function (...)
    _NOVA.COMMAND_DISPATCH.SEND("lua", "push", ...)
end

this.publish = function (...)
    _NOVA.COMMAND_DISPATCH.SEND("lua", "publish", ...)
end

this.schedule = function (...)
    return _NOVA.COMMAND_DISPATCH.CALL("lua", "schedule", ...)
end

this.unschedule = function (...)
    return _NOVA.COMMAND_DISPATCH.CALL("lua", "unschedule", ...)
end

this.unschedule_all = function (...)
    return _NOVA.COMMAND_DISPATCH.CALL("lua", "unschedule_all", ...)
end

this.trigger = function (...)
    _NOVA.TRIGGER_DISPATCH.CALL(...)
end
