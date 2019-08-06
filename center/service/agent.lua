local skynet 		= require "skynet"
local dispatcher 	= require "net.dispatcher"
local socketdriver 	= require "skynet.socketdriver"

local sky_unpack    = skynet.unpack
local str_pack 	    = string.pack
local tb_concat     = table.concat

local fd_sz = string.pack(">J", 1):len()

-- 协议注册（接收'client'类型消息）
skynet.register_protocol({
	name   = "client",
	id     = skynet.PTYPE_CLIENT,
	unpack = skynet.tostring,
})

local session = nil
-- 网络消息分发器
local net_dispatcher = nil

local CMD = {}

function CMD.init()
	net_dispatcher = dispatcher.new()
end

function CMD.connect(source, fd, client_fd)
	session 			= {}
	session.fd 			= fd
	session.client_fd 	= client_fd
	session.user_data 	= {}
end

function CMD.disconnect(source)
	if session then
		local fd 		= session.fd
		local client_fd = session.client_fd
		skynet.send(GLOBAL.SERVICE_NAME.GATE, "lua", "disconnect", fd, client_fd)
		session = nil
	end
	skynet.exit()
end

function CMD.load_data(source, pid)
	local user_data = session.user_data
	if user_data then
		user_data.pid 	= pid
		user_data.state	= 1
		user_data.scene = nil
	end
end

-- 回复客户端消息
function CMD.response(source, proto, message, errorCode)
    if session then
        local fd 		= session.fd
        local client_fd = session.client_fd

        local data =
        {
            header = {
				fd = client_fd,
				proto = proto,
				errcode = errorCode
			},
            payload = message,
        }

        local msg_data = skynet.packstring(data)
        local msg_len = str_pack(">H", msg_data:len())
        local compose_data = {msg_len, msg_data}
        local packet_data = tb_concat(compose_data)

        socketdriver.send(fd, packet_data)
    end
end

-- 内部命令转发
-- 1. 命令来源
-- 2. 命令名称
-- 3. 命令参数
local function command_handler(source, command, ...)
	if session then
		return net_dispatcher:command_dispatch(session, command, ...)
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
		skynet.error("agent---lua--"..cmd)
		local safe_handler = SAFE_HANDLER(session)
		local fn = CMD[cmd]
		if fn then
			safe_handler(fn, source, ...)
		else
			safe_handler(command_handler, source, cmd, ...)
		end
	end)
end)

-- 注册网络消息处理逻辑
skynet.dispatch("client", function(_, _, msg_data)
	msg_data = msg_data:sub(fd_sz + 1)
	local message = sky_unpack(msg_data)
	if session then
		net_dispatcher:message_dispatch(session, message)
	end
end)
