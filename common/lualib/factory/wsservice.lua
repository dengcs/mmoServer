local skynet    = require "skynet"
local socket    = require "skynet.socket"
local websocket = require "http.websocket"

local wsService = {}

function wsService.start(module, mode)
    if mode == "agent" then
        assert(module)
        assert(module.on_message)

        local handle = {}

        function handle.connect(id)
            skynet.error("websocket connect from: " .. tostring(id))

            if module.on_connect then
                module.on_connect(id)
            end
        end

        function handle.handshake(id, header, url)
            local addr = websocket.addrinfo(id)
            skynet.error("websocket handshake from: " .. tostring(id), "url", url, "addr:", addr)
            skynet.error("----header-----")
            for k,v in pairs(header) do
                skynet.error(k,v)
            end
            skynet.error("--------------")
        end

        function handle.message(id, msg, msg_type)
            assert(msg_type == "binary" or msg_type == "text")
            module.on_message(id, msg)
        end

        function handle.ping(id)
            skynet.error("websocket ping from: " .. tostring(id) .. "\n")
        end

        function handle.pong(id)
            skynet.error("websocket pong from: " .. tostring(id))
        end

        function handle.close(id, code, reason)
            skynet.error("websocket close from: " .. tostring(id), code, reason)

            if module.on_disconnect then
                module.on_disconnect(id)
            end
        end

        function handle.error(id)
            skynet.error("websocket error from: " .. tostring(id))
        end

        if module.on_init then
            skynet.init(module.on_init)
        end

        skynet.start(function ()
            skynet.dispatch("lua", function (_,_, id, protocol, addr)
                local ok, err = websocket.accept(id, handle, protocol, addr)
                if not ok then
                    LOG_ERROR("wsservice accept error[%s]", tostring(err))
                end
            end)
        end)
    else
        local CMD = {}

        function CMD.init(source, conf)
            conf.ip           = conf.ip or "0.0.0.0"
            conf.maxclient    = conf.maxclient or 1024
            assert(conf.port, "配置缺少port项")

            local agents = {}
            for i= 1, 10 do
                agents[i] = skynet.newservice(SERVICE_NAME, "agent")
            end
            local balance = 1
            local protocol = "ws"

            local address = string.format("%s:%d",conf.ip, conf.port)
            skynet.error("Listening "..address)
            local listen_id = assert(socket.listen(conf.ip, conf.port))
            socket.start(listen_id , function(socket_id, addr)
                skynet.send(agents[balance], "lua", socket_id, protocol, addr)
                balance = balance + 1
                if balance > #agents then
                    balance = 1
                end
            end)
        end

        skynet.start(function()
            skynet.dispatch("lua", function (session, source, cmd, ...)
                local safe_handler = SAFE_HANDLER(session)
                local f = CMD[cmd]
                if f then
                    safe_handler(f, source, ...)
                end
            end)
        end)
    end
end

return wsService