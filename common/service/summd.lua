local summservice = require "service_factory.summservice"

local skynet = require "skynet"

local server = {}

local node_online = {}

function server.open_handler(name, service)
    assert(not node_online[name], string.format("open: %s: service already exists", name))
    node_online[name] = service
end

function server.close_handler(name)
    node_online[name] = nil
end

local CMD = {}

function CMD.join(source, name, uid, agent, cb, ...)
    local service = summservice.do_query(name)
    if not service then
        ERROR(EFAULT, "find: %s: no such function or service", name)
    end

    local ok, result = skynet.call(service, "lua", "join", uid, agent, cb, ...)
    if ok ~= 0 then
        return ok
    end

    return result
end

function CMD.leave(source, name, uid, ...)
    local service = summservice.do_query(name)
    if not service then
        ERROR(EFAULT, "find: %s: no such function or service", name)
    end

    local ok, result = skynet.call(service, "lua", "leave", uid, ...)
    if ok ~= 0 then
        return ok
    end

    return result
end

function CMD.send(source, name, subcmd, ...)
    local service = summservice.do_query(name)
    if not service then
        ERROR(EFAULT, "find: %s: no such function or service", name)
    end

    skynet.send(service, "lua", subcmd, ...)
end

function CMD.call(source, name, subcmd, ...)
    local service = summservice.do_query(name)
    if not service then
        ERROR(EFAULT, "find: %s: no such function or service", name)
    end

    local ok, result = skynet.call(service, "lua", subcmd, ...)
    if ok ~= 0 then
        ERROR(ok, result)
    end

    return result
end

function server.command_handler(source, cmd, ...)
    local f = CMD[cmd]
    if f then
        return f(source, ...)
    else
        ERROR(EFAULT, "call: %s: command not found", cmd)
    end
end

summservice.start(server)
