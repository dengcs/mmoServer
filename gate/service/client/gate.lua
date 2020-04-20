local skynet 		= require "skynet_ex"
local pbhelper      = require "net.pbhelper"
local wsservice 	= require "factory.wsservice"
local random		= require "utils.random"
local websocket 	= require "http.websocket"

local MODE = ...

local encode 	= pbhelper.pb_encode
local decode 	= pbhelper.pb_decode

local MSG_STATE = {
	PREPARE 	= 0,
	HANDSHAKE	= 1,
	REQUEST		= 2,
}

local sessions 			= {}
local session_map		= {}

local generate_token	= random.Get(10000)

---------------------------------------------------------------------
--- 内部函数
---------------------------------------------------------------------

-- 回复消息
local function response(message)
	local fd	= message.header.fd
	local session = sessions[fd]
	if session then
		local protoName = message.header.proto
		local data      = message.payload
		local errCode   = message.header.errcode
		local msgData 	= encode(protoName, data, errCode)
		websocket.write(fd, msgData, "binary")
	end
end

-- 返回客户端消息
local function resp_msg(fd, proto, data)
	local message = {
		header = {
			fd		= fd,
			proto 	= proto,
		},
		payload = data
	}

	response(message)
end

-- 推送消息的代理
local function send_to_proxy(cmd, fd, msg)
	skynet.send(GLOBAL.SERVICE_NAME.LOGICPROXY, "lua", cmd, fd, msg)
	skynet.send(GLOBAL.SERVICE_NAME.GAMEPROXY, "lua", cmd, fd, msg)
end

-- 游戏服协议匹配
local function game_proto_find(proto)
	local prefix_list = {"game_", "room_", "mail_", "friend_", "chat_"}
	for _, prefix in pairs(prefix_list) do
		if proto:find(prefix)==1 then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------
--- 服务导出接口
---------------------------------------------------------------------
local CMD = {}

-- 返回消息到客户端
function CMD.response(message)
	response(message)
end

---------------------------------------------------------------------
--- 服务事件回调（底层事件通知）
---------------------------------------------------------------------
local server = {}

function server.on_init()
	pbhelper.register()
end

function server.on_connect(fd)
	local session = {
		fd			= fd,
		state		= MSG_STATE.PREPARE
	}
	sessions[fd] = session
end

function server.on_disconnect(fd)
	local session = sessions[fd]
	if session then
		sessions[fd] = nil
		send_to_proxy("signal", fd, "disconnect")

		if session.state == MSG_STATE.REQUEST then
			session_map[session.account] = nil
		end
	end
end

function server.on_message(fd, message)
    local session = sessions[fd]
    if session then
		local msg = decode(message)
		if msg then
			local proto 	= msg.header.proto
			if session.state == MSG_STATE.REQUEST then
				if game_proto_find(proto) then
					skynet.send(GLOBAL.SERVICE_NAME.GAMEPROXY, "lua", "forward", fd, msg)
				else
					skynet.send(GLOBAL.SERVICE_NAME.LOGICPROXY, "lua", "forward", fd, msg)
				end
			else
				local message	= msg.payload

				if message then
					if session.state == MSG_STATE.PREPARE then
						-- 需要记录账号信息（比如IP）
						if proto == "register" then
							-- 记录token
							local account 	= message.account
							local acc_len	= string.len(account)
							if acc_len > 0 and acc_len < 100 then
								local pre_session = session_map[account]
								if pre_session then
									pre_session.state = MSG_STATE.HANDSHAKE
									resp_msg(pre_session.fd, "kick_notify", {reason = 0})
								end
								session_map[account] = session

								generate_token	= generate_token + 1
								session.token 	= generate_token
								session.account = account
								session.state 	= MSG_STATE.HANDSHAKE
								resp_msg(fd, "register_resp", {token = generate_token})
							end
						end
					elseif session.state == MSG_STATE.HANDSHAKE then
						-- 验证token
						if proto == "verify" then
							if session.token == message.token then
								session.state = MSG_STATE.REQUEST
								-- 和逻辑服建立虚拟连接
								send_to_proxy("signal", fd, "connect")
								resp_msg(fd, "verify_resp", {ret = 0})
							end
						end
					end
				end
			end
		end
    end
end

function server.command(cmd,...)
    local fn = CMD[cmd]
    if fn then
      	return fn(...)
    end
end

wsservice.start(server, MODE)