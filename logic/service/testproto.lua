local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "websocket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local protobuf = require "protobuf"


local handler = {}
function handler.on_open(ws)
    print(string.format("%d::open", ws.id))
end

function handler.on_message(ws, message)
    print("on_message")
    
    local base = protobuf.decode("game.NetMessage",message)
    
    print("dcs1--"..table.tostring(base))
    
    local awesome = protobuf.decode("game.AwesomeMessage",base.payload)
    
    print("dcs2--"..table.tostring(awesome))
end

function handler.on_close(ws, code, reason)
    print(string.format("%d close:%s  %s", ws.id, code, reason))
end

local function handle_socket(id)
    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
    if code then
        
        if header.upgrade == "websocket" then
            local ws = websocket.new(id, header, handler)
            ws:start()
        end
    end


end

skynet.start(function()
    protobuf.register_file("./logic/lualib/config/proto/pb/base.pb")
    protobuf.register_file("./logic/lualib/config/proto/pb/awesome.pb")
    local address = "0.0.0.0:8002"
    skynet.error("Listening "..address)
    local id = assert(socket.listen(address))
    socket.start(id , function(id, addr)
       socket.start(id)
       pcall(handle_socket, id)
    end)
end)
