local skynet = require "skynet"

local userdriver = {}

local function __comm_send(addr, command, ...)
    skynet.send(addr, "lua", command, ...)
end

local function __comm_call(addr, command, ...)
    return skynet.call(addr, "lua", command, ...)
end

local function __db_send(command, ...)
    __comm_send(GLOBAL.SERVICE_NAME.DATABASED, command, ...)
end

local function __db_call(command, ...)
    return __comm_call(GLOBAL.SERVICE_NAME.DATABASED, command, ...)
end

local function __dc_send(command, ...)
    __comm_send(GLOBAL.SERVICE_NAME.DATACACHED, command, ...)
end

local function __dc_call(command, ...)
    return __comm_call(GLOBAL.SERVICE_NAME.DATACACHED, command, ...)
end

local function __uc_send(command, ...)
    __comm_send(GLOBAL.SERVICE_NAME.USERCENTERD, command, ...)
end

local function __uc_call(command, ...)
    return __comm_call(GLOBAL.SERVICE_NAME.USERCENTERD, command, ...)
end

function userdriver.db_insert(db, sql)
    return userdriver.db_update(db, sql)
end

function userdriver.db_delete(db, sql)
    return userdriver.db_update(db, sql)
end

function userdriver.db_update(db, sql)
    local errno, result = __db_call("set", db, sql)
    if errno > 0 then
        return nil
    end

    if result.errno then
        LOG_ERROR(table.tostring(result))
        return nil
    end
    return result
end

function userdriver.db_select(db, sql)
    local errno, result = __db_call("get", db, sql)
    if errno > 0 then
        return nil
    end

    if result.errno then
        LOG_ERROR(table.tostring(result))
        return nil
    end
    return result
end

function userdriver.dc_set(db, key, val)
    local errno, result = __dc_call("set", db, key, val)
    if errno > 0 then
        return nil
    end

    if result.errno then
        LOG_ERROR(table.tostring(result))
        return nil
    end
    return result
end

function userdriver.dc_del(db, key)
     __dc_send("del", db, key)
end

function userdriver.dc_get(db, key)
    local errno, result = __dc_call("get", db, key)
    if errno > 0 then
        return nil
    end

    if result.errno then
        LOG_ERROR(table.tostring(result))
        return nil
    end
    return result
end

function userdriver.userdata(uid, name)
    return __uc_call("userdata", uid, name)
end

function userdriver.usersend(uid, cmd, ...)
    __uc_send("usersend", uid, cmd, ...)
end

function userdriver.usercall(uid, cmd, ...)
    return __uc_call("usercall", uid, cmd, ...)
end

return userdriver
