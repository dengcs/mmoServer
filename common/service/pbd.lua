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
    local message,result = pbhelper.pb_decode(data)
    return {info = message,data = result}
end

function server.init_handler()
    local new_pbs = {}
    for _,v in pairs(pbs) do
        local node = assert(skynet.getenv("node"),"getenv获取不到node值！")
        local bp_file = string.format("./%s/%s/%s",node,"lualib/config/proto/pb",v)
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
        return f(...)
    else
        ERROR(EFAULT, "call: %s: command not found", cmd)
    end
end

service.start(server)
