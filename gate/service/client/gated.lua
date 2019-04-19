local skynet 		= require "skynet_ex"
local pbhelper      = require "net.pbhelper"
local wsservice 	= require "factory.wsservice"

local encode = pbhelper.pb_encode
local decode = pbhelper.pb_decode

local sessions = {}

local CMD = {}
local handler = {}

-- 返回消息到客户端
function CMD.response(message)
	local fd        = message.header.fd
	local session = sessions[fd]
	if session then
		local web_socket = session.web_socket
		if web_socket then
			local protoName = message.header.proto
			local data      = message.payload
			local errCode   = message.error.code
			local msgData 	= encode(protoName, data, errCode)
			web_socket:send_binary(msgData)
		end
	end
end

function handler.on_open(conf)
	pbhelper.register()
end

function handler.on_connect(web_socket)
	local fd = web_socket.id
	local session = sessions[fd]
	if not session then
		local session = { web_socket = web_socket }
		sessions[fd] = session
	else
		session.web_socket = web_socket
	end

	skynet.send(GLOBAL.SERVICE_NAME.RELAY, "lua", "signal", fd, "connect")
end

function handler.on_disconnect(fd)
    local session = sessions[fd]
    if session then
        sessions[fd] = nil
    end

	skynet.send(GLOBAL.SERVICE_NAME.RELAY, "lua", "signal", fd, "disconnect")
end

function handler.on_message(fd, message)
    local session = sessions[fd]
    if session then
		local msg = decode(message)
		if msg then
			-- 需要记录账号信息（比如IP）
			if session.sign then
				skynet.send(GLOBAL.SERVICE_NAME.RELAY, "lua", "forward", fd, msg)
			else
				if msg.header.proto == "account_login" then
					skynet.send(GLOBAL.SERVICE_NAME.RELAY, "lua", "signal", fd, "token")
					session.sign = true
				end
			end
		end
    end
end

function handler.command(cmd,...)
    local fn = CMD[cmd]
    if fn then
      	return fn(...)
    end
end

wsservice.start(handler)