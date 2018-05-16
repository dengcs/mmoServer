local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "websocket"
local httpd = require "http.httpd"
local urllib = require "http.url"
local sockethelper = require "http.sockethelper"

local wsService = {}

function wsService.start(processor)
    assert(processor)
    local maxclient = 5000 -- max client
    local client_number = 0
    local connection = {}
    
    local CMD = {}
    local handler = {}
    function handler.on_open(ws)
        print(string.format("%d::open", ws.id))
        
        if processor.on_connect then
            processor.on_connect(ws)
        end
        
        connection[ws.id] = ws
        client_number = client_number + 1
    end
    
    function handler.on_message(ws, message)
        print(string.format("%d receive:%s", ws.id, message))
        
        local c = connection[ws.id]
        if c then
            if processor.on_message then
                processor.on_message(ws, message)
            end
        end
    end
    
    function handler.on_close(ws, code, reason)
        print(string.format("%d close:%s  %s", ws.id, code, reason))
        
        local c = connection[ws.id]
        if c then
            if processor.on_disconnect then
                processor.on_disconnect(ws, code, reason)
            end
            
            connection[ws.id] = nil
            client_number = client_number - 1
        end
    end
    
    -- 关闭客户端
    function CMD.logout(fd)
      local ws = connection[fd]
      if ws then
          ws:close()
      end
    end
    
    -- 返回消息到客户端
    function CMD.response(fd,msg)
        local ws = connection[fd]
        if ws then
            ws:send_binary(msg)
        end
    end
    
    local function handle_open(socket_id)
        if processor.on_open then
            processor.on_open(socket_id)
        end
    end
    
    local function handle_close(socket_id)
        socket.close(socket_id)
        if processor.on_close then
            processor.on_close(socket_id)
        end
    end
    
    
    local function handle_socket(id, addr)
        -- limit request body size to 8192 (you can pass nil to unlimit)
        local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
        if code then
            if header.upgrade == "websocket" then
                local conf = {addr = addr}
                local ws = websocket.new(id, header, handler, conf)
                if ws then
                    ws:start()
                else
                    handle_close(id)
                end
            else
                handle_close(id)
            end
        end  
    end
    
    local conf = processor.configure()
    
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
                handle_open(socket_id)
                socket.start(socket_id)
                pcall(handle_socket, socket_id, addr)
            end
        end)
        
        skynet.dispatch("lua", function (_, address, cmd, ...)
          local f = CMD[cmd]
          if f then
            skynet.ret(skynet.pack(f(...)))
          else
            skynet.ret(skynet.pack(processor.command(cmd,...)))
          end
        end)
    end)
end

return wsService