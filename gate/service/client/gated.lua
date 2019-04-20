local skynet 		= require "skynet_ex"
local pbhelper      = require "net.pbhelper"
local wsservice 	= require "factory.wsservice"
local random		= require "utils.random"

local encode = pbhelper.pb_encode
local decode = pbhelper.pb_decode

local MSG_STATE = {
	PREPARE 	= 0,
	HANDSHAKE	= 1,
	REQUEST		= 2,
}

local sessions = {}

local function response(message)
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

local function resp_msg(fd, proto, data)
	local message = {
		header = {
			fd		= fd,
			proto 	= proto,
		},
		error = {
			code = 0
		},
		payload = data
	}

	response(message)
end

local CMD = {}

-- 返回消息到客户端
function CMD.response(message)
	response(message)
end

local handler = {}

function handler.on_open(conf)
	pbhelper.register()
end

function handler.on_connect(web_socket)
	local fd = web_socket.id
	local session = sessions[fd]
	if not session then
		local session = {
			web_socket 	= web_socket,
			state		= MSG_STATE.PREPARE
		}
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
			if session.state == MSG_STATE.REQUEST then
				skynet.send(GLOBAL.SERVICE_NAME.RELAY, "lua", "forward", fd, msg)
			else
				local proto 	= msg.header.proto
				local message	= msg.payload

				if message then
					if session.state == MSG_STATE.PREPARE then
						-- 需要记录账号信息（比如IP）
						if proto == "register" then
							-- 记录token
							session.token = random.Get(100000000)
							session.state = MSG_STATE.HANDSHAKE
							resp_msg(fd, "register_resp", {token = session.token})
						end
					elseif session.state == MSG_STATE.HANDSHAKE then
						-- 验证token
						if proto == "verify" then
							local ret = 1
							if session.token and session.token == message.token then
								session.state = MSG_STATE.REQUEST
								ret = 0
							end
							resp_msg(fd, "verify_resp", {ret = ret})
						end
					end
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