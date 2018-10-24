local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "websocket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
require "assembly"

local wsService = {}

function wsService.start(handler)
    assert(handler)
    
    local maxclient = 5000 -- max client
	local client_number = 0
    
    local CMD = {}
    
    local function on_connect(socket_id)
        if handler.on_connect then
            handler.on_connect(socket_id)
        end
        client_number = client_number + 1
        print("on_connect client_number:"..client_number)
    end
    
    local function on_disconnect(socket_id)
        if handler.on_disconnect then
            handler.on_disconnect(socket_id)
        end
        client_number = client_number - 1
        print("on_disconnect client_number:"..client_number)
    end
    
    
    local function accept(id, addr)
        -- limit request body size to 8192 (you can pass nil to unlimit)
        local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
        if code then
            if header.upgrade == "websocket" then
                local conf = {addr = addr}
                local ws = websocket.new(id, header, handler, conf)
                if ws then
                    ws:start()
                    return true
                end
            end
        end
        return false
    end
    
    local conf = handler.configure()
    
    skynet.start(function()
        assert(conf.ip, "配置缺少ip项")
        assert(conf.port, "配置缺少port项")
        local address = string.format("%s:%d",conf.ip,conf.port)
        skynet.error("Listening "..address)
        local listen_id = assert(socket.listen(conf.ip,conf.port))
        socket.start(listen_id , function(socket_id, addr)
            -- 最大连接数
            if client_number > maxclient then
                socket.close(socket_id)
            else
                on_connect(socket_id)
                socket.start(socket_id)
                local ok = pcall(accept, socket_id, addr)
                if not ok then
                	on_disconnect(socket_id)
                end
            end
        end)
        
        skynet.dispatch("lua", function (session, source, cmd, ...)
            local safe_handler = SAFE_HANDLER(session)
            local f = CMD[cmd]
            if f then
                return safe_handler(f, source, ...)
            else
                return safe_handler(handler.command, cmd, ...)
            end
        end)
    end)
end

return wsService