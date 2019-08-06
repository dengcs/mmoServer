local skynet 		= require "skynet_ex"
local pbhelper      = require "net.pbhelper"
local wsservice 	= require "factory.wsservice"
local cluster		= require "skynet.cluster"

local tb_insert = table.insert
local encode 	= pbhelper.pb_encode
local decode 	= pbhelper.pb_decode

local MSG_STATE = {
	PREPARE 	= 0,
	HANDSHAKE	= 1,
	REQUEST		= 2,
}

local sessions 			= {}
local token_data_map	= {}

-- 每分钟清理下session
local interval = 60

---------------------------------------------------------------------
--- 内部函数
---------------------------------------------------------------------

-- 回复消息
local function response(message)
	local token	= message.header.fd
	local token_data = token_data_map[token]
	if token_data then
		local session = token_data.session
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
end

-- 返回客户端消息
local function resp_msg(token, proto, data)
	local message = {
		header = {
			fd		= token,
			proto 	= proto,
		},
		payload = data
	}

	response(message)
end

-- 推送消息的代理
local function send_to_proxy(cmd, token, msg)
	skynet.send(GLOBAL.SERVICE_NAME.LOGICPROXY, "lua", cmd, token, msg)
	skynet.send(GLOBAL.SERVICE_NAME.GAMEPROXY, "lua", cmd, token, msg)
end

-- 清理过期token
local function clean_token()
	local now = skynet.now()

	local clear_list = {}
	for token, v in pairs(token_data_map) do
		if v.expiry then
			if v.expiry > 0 and now > v.expiry then
				-- 跟逻辑服断开虚拟连接
				send_to_proxy("signal", token, "disconnect")
				tb_insert(clear_list, token)
			end
		end
	end

	for i, v in pairs(clear_list) do
		token_data_map[v] = nil
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
local handler = {}

function handler.on_open(conf)
	pbhelper.register()

	this.schedule(clean_token , interval, SCHEDULER_FOREVER)
end

function handler.on_connect(web_socket)
	local fd = web_socket.id
	local session = {
		web_socket 	= web_socket,
		state		= MSG_STATE.PREPARE
	}
	sessions[fd] = session
end

function handler.on_disconnect(fd)
	local token = nil
	local session = sessions[fd]
	if session then
		if session.state == MSG_STATE.REQUEST then
			token = session.token
		end
	end

	if token then
		local token_data = token_data_map[token]
		if token_data then
			local expiry = skynet.now() + interval
			token_data.expiry 	= expiry
			token_data.session	= nil
		end
	end

	sessions[fd] = nil
end

function handler.on_message(fd, message)
    local session = sessions[fd]
    if session then
		local msg = decode(message)
		if msg then
			local proto 	= msg.header.proto
			if session.state == MSG_STATE.REQUEST then
				if game_proto_find(proto) then
					skynet.send(GLOBAL.SERVICE_NAME.GAMEPROXY, "lua", "forward", session.token, msg)
				else
					skynet.send(GLOBAL.SERVICE_NAME.LOGICPROXY, "lua", "forward", session.token, msg)
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
								local token_data = token_data_map[token]
								if token_data then
									local pre_session = token_data.session
									if pre_session then
										pre_session.state = MSG_STATE.PREPARE
										resp_msg(token, "kick_notify", {reason = 0})
									end
								else
									token_data = {}
									token_data_map[token] = token_data
								end

								token_data.session = session

								session.token = token
								session.state = MSG_STATE.HANDSHAKE
								resp_msg(token, "register_resp", {token = token})
							end
						end
					elseif session.state == MSG_STATE.HANDSHAKE then
						-- 验证token
						if proto == "verify" then
							local ret = 1
							if session.token and session.token == message.token then
								session.state = MSG_STATE.REQUEST
								ret = 0
								-- 和逻辑服建立虚拟连接
								send_to_proxy("signal", session.token, "connect")
								resp_msg(session.token, "verify_resp", {ret = ret})
							end
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