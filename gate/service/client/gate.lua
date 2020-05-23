local skynet 		= require "skynet_ex"
local pbhelper      = require "net.pbhelper"
local wsservice 	= require "factory.wsservice"
local random		= require "utils.random"
local wshelper 		= require "wshelper"
local centerproxy 	= require "proxy.centerproxy"
local logicproxy 	= require "proxy.logicproxy"
local arenaproxy 	= require "proxy.arenaproxy"

local MODE = ...

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
		wshelper.write(fd, message)
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
local function signal_to_proxy(fd, msg)
	logicproxy.signal(fd, msg)
	centerproxy.signal(fd, msg)
	arenaproxy.signal(fd, msg)
end

-- 中心服协议匹配
local function center_proto_find(proto)
	local prefix_list = {"room_", "mail_", "friend_", "chat_"}
	for _, prefix in pairs(prefix_list) do
		if proto:find(prefix)==1 then
			return true
		end
	end
	return false
end

-- 战斗服协议匹配
local function arena_proto_find(proto)
	local prefix_list = {"game_"}
	for _, prefix in pairs(prefix_list) do
		if proto:find(prefix)==1 then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------
--- 服务事件回调（底层事件通知）
---------------------------------------------------------------------
local server = {}

function server.on_init()
	pbhelper.register()
	logicproxy.init()
	centerproxy.init()
	arenaproxy.init()
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
		signal_to_proxy(fd, "disconnect")

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
				if center_proto_find(proto) then
					centerproxy.forward(fd, msg)
				elseif arena_proto_find(proto) then
					arenaproxy.forward(fd, msg)
				else
					logicproxy.forward(fd, msg)
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
								signal_to_proxy(fd, "connect")
								resp_msg(fd, "verify_resp", {ret = 0})
							end
						end
					end
				end
			end
		end
    end
end

wsservice.start(server, MODE)