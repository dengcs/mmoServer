---------------------------------------------------------------------
--- 简单'web'服务
---------------------------------------------------------------------
local service = require "factory.service"
local skynet  = require "skynet"
local json    = require "cjson"
local url     = require "http.url"
local router  = require "router"

-- 服务启动参数
-- 1. svcname  - 服务名称
-- 2. instance - 实例数量
local svcname, instance = ...
assert(svcname, "svcname is nil!!!")

---------------------------------------------------------------------
--- 服务导出接口
---------------------------------------------------------------------
local COMMAND = {}

-- 注册'web'请求处理逻辑
-- 1. 注册内容
function COMMAND.register(routers)
	if type(routers) == "string" then
		require(routers)
	else
		for _, v in pairs(routers) do
			require(v)
		end
	end
	return 0
end

---------------------------------------------------------------------
--- 网关回调逻辑
---------------------------------------------------------------------
local server = 
{
	name     = tostring(svcname ),
	instance = tonumber(instance) or 1,
}

-- 服务开启通知
-- 1. 服务配置
function server.init_handler(configure)
	if configure.router then
		this.call("register", configure.router)
	end
end

-- 服务退出通知
function server.exit_handler()
end

-- 网络请求处理
-- 1. 应答接口
-- 2. 请求路径
-- 3. 请求类型
-- 4. 消息头
-- 5. 消息内容
function server.message_handler(response, path, method, header, body)
	-- 构造请求结构
	local req = 
	{
		method = string.lower(method),
		body   = body,
		url    = {},
		query  = nil,
	}
	-- 解析请求路径
	req.url.path, req.query = url.parse(path)
	if req.query then
		req.query = url.parse_query(req.query)
	end
	if string.sub(req.url.path, -1, -1) ~= "/" then
		req.url.path = req.url.path .. "/"
	end
	-- 构造应答结构
	local res = 
	{
		-- 普通应答逻辑（仅返回状态码）
		status = response,
		-- 普通应答逻辑（返回附加数据）
		send = function(message)
			response(200, message)
		end,
		-- JSON应答逻辑（返回JSON数据）
		json = function(message)
			response(200, json.encode(message))
		end,
	}
	-- 处理网络请求
	router.request_handler(req, res)
end

-- 内部命令处理
-- 1. 命令来源
-- 2. 命令名称
-- 3. 命令参数
function server.command_handler(source, cmd, ...)
	local fn = COMMAND[cmd]
	if fn then
		return fn(...)
	else
		ERROR("command[%s] can't found!!!", cmd)
	end
end

-- 启动'web'服务
service.web.start(server)
