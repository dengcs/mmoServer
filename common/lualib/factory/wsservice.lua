local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "websocket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"

local wsService = {}

function wsService.start(handler)
    assert(handler)
    assert(handler.on_message)

    local client_number = 0

    local service = {}

    function service.connect(ws)
        client_number = client_number + 1

        if handler.on_connect then
            handler.on_connect(ws)
        end
    end

    function service.disconnect(fd)
        client_number = client_number - 1

        if handler.on_disconnect then
            handler.on_disconnect(fd)
        end
    end

    function service.message(fd, msgData)
        handler.on_message(fd, msgData)
    end


    local function accept(fd, addr)
        -- limit request body size to 8192 (you can pass nil to unlimit)
        local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(fd), 8192)
        if code then
            if header.upgrade == "websocket" then
                local params =
                {
                    addr = addr,
                    check_origin = false,
                }
                local ws = websocket.new(fd, header, service, params)
                if ws then
                    ws:start()
                    return true
                end
            end
        end
        return false
    end

    local CMD = {}

    function CMD.open(source, conf)
        conf.ip           = conf.ip or "0.0.0.0"
        conf.maxclient    = conf.maxclient or 1024

        assert(conf.ip, "配置缺少ip项")
        assert(conf.port, "配置缺少port项")
        local address = string.format("%s:%d",conf.ip, conf.port)
        skynet.error("Listening "..address)
        local listen_id = assert(socket.listen(conf.ip, conf.port))
        socket.start(listen_id , function(socket_id, addr)
            -- 最大连接数
            if client_number > conf.maxclient then
                socket.close(socket_id)
            else
                socket.start(socket_id)
                local ok = pcall(accept, socket_id, addr)
                if not ok then
                    socket.close(socket_id)
                end
            end
        end)
    end

    skynet.start(function()
        skynet.dispatch("lua", function (session, source, cmd, ...)
            local safe_handler = SAFE_HANDLER(session)
            local f = CMD[cmd]
            if f then
                safe_handler(f, source, ...)
            else
                safe_handler(handler.command, cmd, ...)
            end
        end)
    end)
    end

return wsService