local service = require "factory.service"

local pb_buffers = {}

local server = {}

local CMD = {}

function CMD.read_pb_buffer(node, filename)
    local node_buffers = pb_buffers[node]
    if not node_buffers then
        pb_buffers[node] = {}
        node_buffers = pb_buffers[node]
    end

    local buffer = node_buffers[filename]
    if not buffer then
        local filepath = "lualib/config/proto/pb"
        local bp_file = string.format("./%s/%s/%s", node, filepath, filename)
        local f = assert(io.open(bp_file , "rb"))
        buffer = f:read "*a"
        f:close()

        node_buffers[filename] = buffer
    end
    return buffer
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
