---------------------------------------------------------------------
--- 消息分发中间件
---------------------------------------------------------------------
local lfs      		= require "lfs"
local skynet 		= require "skynet"
local socketdriver 	= require "skynet.socketdriver"

local pairs		= pairs
local xpcall	= xpcall
local assert	= assert
local strpack 	= string.pack
local tinsert 	= table.insert
local tconcat 	= table.concat
local strfmt	= string.format

-- 遍历指定目录（递归）
-- 1. 目录路径
-- 2. 文件后缀
-- 3. 文件集合
local function traverse(root, collect)
	collect = collect or {}
	for element in lfs.dir(root) do
		if (element ~= ".") and (element ~= "..") then
			local path = strfmt("%s/%s", root, element)
			local attr = lfs.attributes(path)
			if attr.mode == "directory" then
				traverse(path, collect)
			else
				local file_name = element:match("(.+)%.%w+$")
				tinsert(collect, file_name)
			end
		end
	end
	return collect
end

local M = {}
M.HANDSHAKE 	= {}			-- 握手相关请求处理逻辑集合（确保'握手/重连'请求仅在指定状态有效）
M.PREPARE   	= {}			-- 选角相关请求处理逻辑集合（确保'选角/创角'请求仅在指定状态有效）
M.REQUEST   	= {}			-- 普通请求
M.COMMAND   	= {}			-- 内部命令
M.TRIGGER   	= {}			-- 事件处理

-- 构造'dispatcher'对象
function M.new()
	local o = {}
	setmetatable(o, {__index = M})

	o:register_handle()

	return o
end

function M:register_handle()
	local node = assert(skynet.getenv("node"),"getenv获取不到node值！")
	local root = strfmt("./%s/lualib/handler", node)
	local files = traverse(root)
    for _,v in pairs(files or {}) do
		local handler = require(strfmt("handler.%s", v))
        self:register(handler)
    end
end

-- 注册消息处理逻辑
-- 1. 配置参数
function M:register(handler)
	-- 注册'握手/重连'相关请求处理逻辑
	for k, v in pairs(handler.HANDSHAKE or {}) do
		self.HANDSHAKE[k] = v
	end
	-- 注册'选角/创角'相关请求处理逻辑
	for k, v in pairs(handler.PREPARE or {}) do
		self.PREPARE[k] = v
	end
	-- 注册正常状态网络数据处理逻辑
	for k, v in pairs(handler.REQUEST or {}) do
		self.REQUEST[k] = v
	end
	-- 注册内部命令处理逻辑
	for k, v in pairs(handler.COMMAND or {}) do
		self.COMMAND[k] = v
	end
	-- 注册事件触发处理逻辑
	for _, v in pairs(handler.TRIGGER or {}) do
		tinsert(self.TRIGGER, v)
	end
end

-- 内部命令快速访问包装接口
-- 1. 命令集合
-- 2. 命令名称
-- 3. 执行参数
local function command_execute(commands, cmd, ...)
	local fn = commands[cmd]
	if fn then
		return fn(...)
	else
		LOG_ERROR("execute : command[%s] not found!!!", tostring(cmd))
	end
end

-- 请求消息下发包装接口
-- 1. 用户信息
-- 2. 消息名称
-- 3. 消息内容
-- 4. 错误编号
function M:message_response(session, name, message, errno)
	local fd = session.fd or 0
	if fd == 0 then
		return ENONET
	end

	local data =
	{
		header = {fd = session.client_fd, proto = name},
		error = {code = errno},
		payload = message,
	}

	local msg_data = skynet.packstring(data)
	local msg_len = strpack(">H", msg_data:len())
	local compose_data = {msg_len, msg_data}
	local packet_data = tconcat(compose_data)

	socketdriver.send(fd, packet_data)
	return 0
end

-- 构造消息分发用户上下文
-- 1. 用户信息
-- 2. 扩展信息
function M:user_context(session, extra)
	-- 消息下行接口
	-- 1. 消息名称
	-- 2. 消息内容
	-- 3. 错误编号
	local function __message_response(name, message, errno)
		return self:message_response(session, name, message, errno)
	end
	-- 内部命令分发
	-- 1. 命令名称
	-- 2. 执行参数
	local function __command_execute(cmd, ...)
		return command_execute(self.COMMAND, cmd, self:user_context(session), ...)
	end
	-- 事件触发通知
	-- 1. 事件类型
	-- 2. 事件内容
	local function __event_trigger(category, arguments)
		for _, v in pairs(self.TRIGGER) do
			v(self:user_context(session), category, arguments)
		end
	end
	-- 构造用户上下文
	local context = 
	{
		user     = session.model_data,
		response = __message_response,
		call     = __command_execute,
		trigger  = __event_trigger,
	}
	for k, v in pairs(extra or {}) do
		context[k] = v
	end
	return context
end

-- 请求消息快速上行包装接口
-- 1. 消息分发器对象
-- 2. 用户信息
-- 3. 请求内容
-- 4. 方法集合
local function message_request(self, session, message, commands)
	assert(message)
	-- 异常捕捉
	local function traceback()
		LOG_ERROR(debug.traceback())
	end
	-- 协议解析
	local head, proto = message.header, message.payload
	if not head then
		LOG_ERROR("request : message unpack error!!!")
	end
	-- 请求转发
	local ok, retval = xpcall(command_execute, traceback, commands, head.proto, self:user_context(session, {proto = proto}))
	if not ok then
		retval = ENOEXEC
	end
	retval = retval or 0
	if retval > 0 then
		self:message_response(session, head.proto, nil, retval)
	end
	return retval
end

-- 握手相关请求分发
-- 1. 用户信息
-- 2. 请求内容
function M:handshake_dispatch(session, message)
	return message_request(self, session, message, self.HANDSHAKE)
end

-- 选角相关请求分发
-- 1. 用户信息
-- 2. 请求内容
function M:prepare_dispatch(session, message)
	return message_request(self, session, message, self.PREPARE)
end

-- 普通请求分发逻辑
-- 1. 用户信息
-- 2. 请求内容
function M:message_dispatch(session, message)
	return message_request(self, session, message, self.REQUEST)
end

-- 内部命令分发逻辑
-- 1. 用户信息
-- 2. 命令来源
-- 3. 命令名称
-- 4. 命令参数
function M:command_dispatch(session, cmd, ...)
	return command_execute(self.COMMAND, cmd, self:user_context(session), ...)
end

-- 返回消息分发中间件模型
return M
