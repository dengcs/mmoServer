local skynet = require "skynet"

local table = table
local string = string
local assert = assert

-- 加载指定组件（做了个组件嵌套加载的逻辑，不过太晦涩了）
-- 1. 模块路径？？
-- 2. 模块类型？？
function LOAD_MODULE(ref, key, ...)
    local handler

    -- 加载模块配置
    if type(ref) == "string" then
        -- 从指定路径加载模块
        local v = skynet.getenv(ref)
        if not v then
            v = ref
        end
        local conf = require (v)
        handler = conf
    elseif type(ref) == "table" then
        -- 直接指定模块
        handler = ref
    end

    -- ？？
    assert(handler)
    if key then
        -- 调用指定
        local var = handler[key]
        if type(var) == "function" then
            var = var()
        end

        if type(var) == "table" then
            handler = LOAD_MODULE(var, ...)
        else
            assert(not key, string.format("search sub item (%s) failed", tostring(key)))
            handler = var
        end
    end

    return handler
end

function EXCEPTION_MESSAGE(errno, fmt, ...)
    fmt = "[%d] " .. fmt
    return string.format(fmt, errno, ...)
end

local function __ERROR(errno, fmt, ...)
    local msg = EXCEPTION_MESSAGE(errno, fmt, ...)
    error(msg)
end

function ERROR(fmt, ...)
    if type(fmt) == "number" then
        __ERROR(fmt, ...)
    else
        local msg = string.format(fmt, ...)
        error(msg)
    end
end

local function __BLANK_CALL(...)
    return ...
end

local function __PACK_CALL(...)
    return skynet.ret(skynet.pack(...))
end

function SAFE_RESPONSE(session, ...)
    if not session then
        return __BLANK_CALL(...)
    elseif session > 0 then
        return __PACK_CALL(...)
    else
        return nil
    end
end

function INTERRUPT_SERVICE_RESPONSE(session)
    return SAFE_RESPONSE(session, ECHILD, "The service has been closed.")
end

function RESPONSE_SERVICE_RESULT(session, msg)
    if not session then
        return table.unpack(msg)
    else
        return msg
    end
end

function AUTO_GC()
    collectgarbage("collect")
end