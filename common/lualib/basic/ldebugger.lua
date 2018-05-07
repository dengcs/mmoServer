local skynet = require "skynet"

local CTL = 3

local KNR = "\x1B[0m"
local KHL = "\x1B[1m"
local KUL = "\x1B[4m"
local KFL = "\x1B[5m"
local KBK = "\x1B[30m"
local KRD = "\x1B[31m"
local KGN = "\x1B[32m"
local KYE = "\x1B[33m"
local KBU = "\x1B[34m"
local KVT = "\x1B[35m"
local KDG = "\x1B[36m"
local KWH = "\x1B[37m"

local function __datetime()
    local t = os.time()
    local s = os.date("%Y-%m-%d %H:%M:%S", t)
    return s
end

local function __caption(head)
    head = head or "UNKNOWN"
    local s = string.format("[%s] %s ", head, __datetime())
    return s
end

local function __exception_info(head, info, clr)
    info = KHL .. __caption(head) .. info .. KNR
    if clr then
        info = clr .. info
    end
    return info
end

local function __exception_traceback(level, top, clr, msg)
    top = top or 0
    clr = clr or KBU
    msg = msg or ""

    local sep = " "
    if top ~= 0 then
        sep = "\n\t"
    end

    local info = debug.getinfo(level)
    if info and info.currentline > 0 then
        local name = info.name
        local src = info.short_src
        local line = info.currentline

        if not name then name = "..." end
        if not src  then src  = "nil" end
        msg = msg .. sep .. clr .. KUL .. string.format("at function: %s (%s:%d)", name, src, line) .. KNR
    end

    level = level + 1
    if level > top then
        return msg
    end
    return __exception_traceback(level, top, clr, msg)
end

local function __record_format(head, info)
    info = __caption(head) .. info
    return info
end

function LOG_DEBUG(fmt, ...)
    local msg = string.format(fmt, ...)
    msg = __exception_info("DEBUG", msg, KDG)
    msg = msg .. __exception_traceback(CTL)
    skynet.error(msg)
end

function LOG_INFO(fmt, ...)
    local msg = string.format(fmt, ...)
    msg = __exception_info("INFO", msg)
    msg = msg .. __exception_traceback(CTL)
    skynet.error(msg)
end

function LOG_WARN(fmt, ...)
    local msg = string.format(fmt, ...)
    msg = __exception_info("WARN", msg, KYE)
    msg = msg .. __exception_traceback(CTL)
    skynet.error(msg)
end

function LOG_ERROR(fmt, ...)
    local msg = string.format(fmt, ...)
    msg = __exception_info("ERROR", msg, KRD)
    msg = msg .. __exception_traceback(CTL, 9, KRD)
    skynet.error(msg)
end

function LOG_FATAL(fmt, ...)
    local msg = string.format(fmt, ...)
    msg = __exception_info("FATAL", msg, KRD)
    msg = msg .. __exception_traceback(CTL, 9, KRD)
    skynet.error(msg)
end