local skynet  = require "skynet"
local service = require "factory.service"

local server = {}

local connection_pools = {}

local initialized = false

local function do_open(conf)
    local connection_pool = require "persistent.mysql_connection_pool"
    local inst = connection_pool.new()

    local ok = inst:start(conf)
    if ok then
        inst:stop()
        return ok
    end

    connection_pools[conf.database] = inst
    return ok
end

local function do_close(db)
    local inst = connection_pools[db]
    if inst then
        inst:stop()

        connection_pools[db] = nil
    end
end

local function init_connection_pool()
    local datasource = skynet.getenv("datasource") or "config.datasource"
    if not datasource then
        ERROR(EFAULT, "Unknown datasource.")
        return EINVAL
    end

    local conf = require (datasource)
    assert(conf and conf.databased)
    
    local ok = do_open(conf.databased)
    if ok then
        return ok
    end

    return 0
end

local function cleanup_connection_pool()
    for k, inst in pairs(connection_pools) do
        assert(inst, "Unknown connection instance.")

        do_close(k)
    end
end

local CMD = {}

function CMD.get(source, db, key)
    local pool = assert(connection_pools[db], "db is nil")
    return pool:do_query("get", key)
end

function CMD.set(source, db, key, value)
    local pool = assert(connection_pools[db], "db is nil")
    return pool:do_update("set", key, value)
end

function CMD.del(source, db, key)
    local pool = assert(connection_pools[db], "db is nil")
    return pool:do_update("del", key)
end

function CMD.exists(source, db, key)
    local pool = assert(connection_pools[db], "db is nil")
    return pool:do_query("exists", key)
end

function server.init_handler(conf)
end

function server.exit_handler()
end

function server.start_handler()
    assert(not initialized, "already starting")

    -- initialize local connection pool
    init_connection_pool()

    return 0
end

function server.stop_handler()
    -- cleanup local connection pool
    cleanup_connection_pool()

    connection_pools = {}

    return 0
end

function server.command_handler(source, cmd, ...)
    local f = CMD[cmd]
    if f then
        return f(source, ...)
    else
        ERROR(EFAULT, "call: %s: command not found", cmd)
    end
end

service.start(server)
