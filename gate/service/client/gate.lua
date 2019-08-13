local skynet 		= require "skynet_ex"
local pbhelper      = require "net.pbhelper"
local wsservice 	= require "factory.wsservice"
local cluster		= require "skynet.cluster"

local encode 	= pbhelper.pb_encode
local decode 	= pbhelper.pb_decode
local tb_insert	= table.insert

local MSG_STATE = {
	PREPARE 	= 0,
	HANDSHAKE	= 1,
	REQUEST		= 2,
}

local sessions 			= {}
local token_sessions	= {}
local fd_expiry_map		= {}

---------------------------------------------------------------------
--- 内部函数
---------------------------------------------------------------------

-- 回复消息
local function response(message)
	local fd	= message.header.fd
	local session = sessions[fd]
	if session then
		local web_socket = session.web_socket
		if web_socket and web_socket:is_alive() then
			local protoName = message.header.proto
			local data      = message.payload
			local errCode   = message.header.errcode
			local msgData 	= encode(protoName, data, errCode)
			web_socket:send_binary(msgData)
		end
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

-- 清理过期session
local function clear_expiry_session()
	local now = skynet.now()

	local clear_list = {}
	for fd, expiry in pairs(fd_expiry_map) do
		if now > expiry then
			-- 跟逻辑服断开虚拟连接
			send_to_proxy("signal", fd, "disconnect")
			tb_insert(clear_list, fd)
		end
	end

	for _,fd in pairs(clear_list) do
		fd_expiry_map[fd] = nil
		sessions[fd] = nil
	end
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

function server.on_init(conf)
	pbhelper.register()

	this.schedule(clear_expiry_session , 60, SCHEDULER_FOREVER)
end

function server.on_connect(web_socket)
	local fd = web_socket.id
	local session = {
		fd			= fd,
		web_socket 	= web_socket,
		state		= MSG_STATE.PREPARE
	}
	sessions[fd] = session
end

function server.on_disconnect(fd)
	local session = sessions[fd]
	if session then
		fd_expiry_map[fd] = skynet.now() + 120
		if session.token then
			token_sessions[session.token] = nil
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
							local ret, token = cluster.call("center", GLOBAL.SERVICE_NAME.TOKEN, "generate", message.account)
							if ret == 0 then
								local pre_session = token_sessions[token]
								if pre_session then
									pre_session.state = MSG_STATE.PREPARE
									pre_session.token = nil
									resp_msg(pre_session.fd, "kick_notify", {reason = 0})
								end
								token_sessions[token] = session

								session.token = token
								session.state = MSG_STATE.HANDSHAKE
								resp_msg(fd, "register_resp", {token = token})
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

wsservice.start(server)