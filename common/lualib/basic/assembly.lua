---------------------------------------------------------------------
--- 服务框架配件模块
---------------------------------------------------------------------
local skynet    = require "skynet"

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
--- 服务框架内部状态
---------------------------------------------------------------------

-- 服务状态枚举
__SERVICE_ESTATE = 
{
    INITIAL  = 1,       -- 初始状态
    PREPARE  = 2,       -- 准备状态
    RUNNING  = 3,       -- 工作状态
    SUSPEND  = 4,       -- 暂停状态
    FINISHED = 5,       -- 退出状态
}

-- 服务状态标志
local __service_state = __SERVICE_ESTATE.INITIAL

-- 是否初始状态
function IS_INITIAL()
    return __service_state == __SERVICE_ESTATE.INITIAL
end

-- 是否准备状态
function IS_PREPARE()
    return __service_state == __SERVICE_ESTATE.PREPARE
end

-- 是否工作状态
function IS_RUNNING()
    return __service_state == __SERVICE_ESTATE.RUNNING
end

-- 是否暂停状态
function IS_SUSPEND()
    return __service_state == __SERVICE_ESTATE.SUSPEND
end

-- 是否退出状态
function IS_FINISHED()
    return __service_state == __SERVICE_ESTATE.FINISHED
end

-- 完成初始化（仅改变状态）
function DO_READY()
    assert(IS_INITIAL())
    __service_state = __SERVICE_ESTATE.PREPARE
end

-- 启动服务（仅变更状态）
function DO_START()
    assert(IS_PREPARE() or IS_SUSPEND())
    __service_state = __SERVICE_ESTATE.RUNNING
end

-- 暂停服务（仅变更状态）
function DO_PAUSE()
    assert(IS_RUNNING())
    __service_state = __SERVICE_ESTATE.SUSPEND
end

-- 退出服务（仅变更状态）
function DO_FINISH()
    __service_state = __SERVICE_ESTATE.FINISHED
end

---------------------------------------------------------------------
--- 服务框架组件模块(记录服务核心状态)
---------------------------------------------------------------------

-- 分发协议集合
__SERVICE_PROTOCOL = {}

-- 服务配件模块
__SERVICE_ASSEMBLY = 
{
    COMMAND_DISPATCH = 
    {
        CALL = function(...) skynet.error("Command dispatch not implemented!!!") end,
    },
    TRIGGER_DISPATCH =
    {
        CALL = function(...) skynet.error("Trigger dispatch not implemented!!!") end,
    },
}

-- 注册指令分发逻辑
-- 1. 协议名称
-- 2. 分发逻辑
function SERVICE_COMMAND_REGISTER(typename, dispatcher)
    -- 逻辑参数检查
    assert(dispatcher)
    assert(typename)
    assert(not __SERVICE_PROTOCOL[typename])
    -- 指令分发逻辑
    local function __dispatcher(session, source, ...)
        if IS_FINISHED() then
            error("Service already exited!!!")
        end
        local retval = { dispatcher(session, source, ...) }
        if IS_FINISHED() then
            skynet.exit()
        else
            return table.unpack(retval)
        end
    end
    -- 注册指令分发逻辑（跨服调用）
    local retval = skynet.dispatch(typename, __dispatcher)
    if retval then
        skynet.error(string.format("Service[%s] : dispatch already registed!!!", typename))
    end
    -- 注册指令分发逻辑（内部调用）
    __SERVICE_PROTOCOL[typename] = __dispatcher
    __SERVICE_ASSEMBLY.COMMAND_DISPATCH = 
    {
        CALL = function(typename, ...)
            return assert(__SERVICE_PROTOCOL[typename])(nil, skynet.self(), ...)
        end,
    }
end

-- 注册事件处理逻辑
-- 1. 处理逻辑
function SERVICE_TRIGGER_REGISTER(fn)
    assert(fn)
    __SERVICE_ASSEMBLY.TRIGGER_DISPATCH = 
    {
        CALL = function(...)
            fn(...)
        end,
    }
end

---------------------------------------------------------------------
--- 内置快速调用接口
--- 模拟面向对象语言结构，将’this‘对象封装为当前服务的一个'伪对象'
---------------------------------------------------------------------
this = {}

function this.usercall(pid, command, ...)
    return skynet.call(GLOBAL.SERVICE.USERCENTERD, "lua", "usercall", pid, command, ...)
end

function this.usersend(pid, command, ...)
    return skynet.send(GLOBAL.SERVICE.USERCENTERD, "lua", "usersend", pid, command, ...)
end

function this.call(command, ...)
    return __SERVICE_ASSEMBLY.COMMAND_DISPATCH.CALL("lua", command, ...)
end

function this.start(...)
    return __SERVICE_ASSEMBLY.COMMAND_DISPATCH.CALL("lua", "start", ...)
end

function this.stop()
    return __SERVICE_ASSEMBLY.COMMAND_DISPATCH.CALL("lua", "stop")
end

function this.collect()
    return __SERVICE_ASSEMBLY.COMMAND_DISPATCH.CALL("lua", "collect")
end

function this.trigger(mode, content)
    return __SERVICE_ASSEMBLY.TRIGGER_DISPATCH.CALL(mode, content)
end

function this.time()
    return math.floor(skynet.time())
end

this.schedule = function (...)
    return __SERVICE_ASSEMBLY.COMMAND_DISPATCH.CALL("lua", "schedule", ...)
end

this.unschedule = function (...)
    return __SERVICE_ASSEMBLY.COMMAND_DISPATCH.CALL("lua", "unschedule", ...)
end

this.unschedule_all = function (...)
    return __SERVICE_ASSEMBLY.COMMAND_DISPATCH.CALL("lua", "unschedule_all", ...)
end
