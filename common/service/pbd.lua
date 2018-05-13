local skynet  = require "skynet"
local service = require "service_factory.service"
local pbhelper = require "net.pbhelper"
local pbs = require "config.proto.pbs"


local server = {}

local CMD = {}

function CMD.encode(uid, name, data, errcode)
    return pbhelper.pb_encode(uid, name, data, errcode)
end

function CMD.decode(data)
    return pbhelper.pb_decode(data)
end

function server.init_handler(conf)
    local new_pbs = {}
    for _,v in pairs(pbs) do
        local bp_file = string.format(".%s/%s/%s",conf.server,"config/proto/pb",v)
        table.insert(new_pbs,bp_file)
    end
    pbhelper.register(new_pbs)
end

function server.exit_handler()
end

function server.start_handler()

    return 0
end

function server.stop_handler()

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
