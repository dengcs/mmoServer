local string = string

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