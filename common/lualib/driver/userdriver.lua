local skynet = require "skynet"

local userdriver = {}

local function __comm_send(addr, command, ...)
    skynet.send(addr, "lua", command, ...)
end

local function __comm_call(addr, command, ...)
    return skynet.call(addr, "lua", command, ...)
end

local function __uc_send(command, ...)
    __comm_send(GLOBAL.SERVICE_NAME.USERCENTERD, command, ...)
end

local function __uc_call(command, ...)
    return __comm_call(GLOBAL.SERVICE_NAME.USERCENTERD, command, ...)
end

function userdriver.userdata(pid, name)
    return __uc_call("userdata", pid, name)
end

function userdriver.usersend(pid, cmd, ...)
    __uc_send("usersend", pid, cmd, ...)
end

function userdriver.usercall(pid, cmd, ...)
    return __uc_call("usercall", pid, cmd, ...)
end

return userdriver
