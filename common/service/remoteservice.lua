-----------------------------------------------------------
--- 服务管理器
-----------------------------------------------------------
local service = require "factory.service"
local method  = require "method"
local skynet  = require "skynet.manager"
local cluster = require "skynet.cluster"

-----------------------------------------------------------
--- 内部变量/内部逻辑
-----------------------------------------------------------

local svcmapping = {}	-- 服务映射集合
local svcordinal = {}	-- 服务关闭顺序

-- 启动指定服务（远程服务仅需创建代理）
-- 1. 节点名称
-- 2. 服务名称
-- 3. 服务脚本
-- 4. 是否唯一服务
-- 5. 自动垃圾回收
-- 6. 服务启动参数
local function open(nodename, svcname, module, unique, collect, configure)
	assert(nodename, "svcmanager : nodename is nil!!!")
	assert(svcname,  "svcmanager : svcname  is nil!!!")
	if svcmapping[svcname] ~= nil then
		ERROR(EFAULT, "svcmanager : duplicate svcname[%s]", svcname)
	end
	-- 创建服务对象
	local service = nil
	if nodename == skynet.getenv("nodename") then
		-- 本地服务
		if unique then
			service = skynet.uniqueservice(module)
		else
			service = skynet.newservice(module)
		end
	else
		-- 远程服务
		service = cluster.proxy(nodename, svcname)
		collect = nil
	end
	skynet.name(svcname, service)
	-- 保存服务记录
	table.insert(svcordinal, 1, svcname)
	svcmapping[svcname] = 
	{
		nodename = nodename,
		service  = service,
		collect  = collect,
	}
	-- 本地服务初始化
	if nodename == skynet.getenv("nodename") then
		local _, retval = skynet.call(service, "lua", "init", configure)
		if retval ~= 0 then
			ERROR(retval, "svcmanager : %s.init() failed!!!", svcname)
		end
	end
	return service
end

-- 关闭指定服务（远程服务仅需关闭代理）
-- 1. 服务名称
local function close(svcname)
	local m = assert(svcmapping[svcname], string.format("svcmanager : %s not exists!!!", svcname))
	-- 关闭指定服务
	if m.nodename == skynet.getenv("nodename") then
		-- 本地服务
		skynet.call(m.service, "lua", "exit")
	end
	-- 移除服务记录
	svcmapping[svcname] = nil
	for i, v in ipairs(svcordinal) do
		if v == svcname then
			table.remove(svcordinal, i)
		end
	end
	return 0
end

-----------------------------------------------------------
--- 服务操作接口
-----------------------------------------------------------
local command = {}

-- 开启指定服务
-- 1. 命令来源
-- 2. 启动配置
function command.open(source, configure)
	local nodename = configure.nodename or skynet.getenv("nodename")
	local svcname  = configure.svcname
	local module   = configure.module
	local unique   = configure.unique
	local collect  = configure.collect
	local s = open(nodename, svcname, module, unique, collect, configure)
	if configure.init then
		for _, c in pairs(configure.init) do
			assert(c.func, string.format("service[%s] : initial-function is nil!!!", svcname))
			skynet.call(s, "lua", c.func, c.args)
		end
	end
end

-- 加载服务配置
-- 1. 命令来源
-- 2. 服务配置
function command.load(source, configures)
	for _, v in pairs(configures) do
		command.open(source, v)
	end
	return 0
end

-- 关闭指定服务
-- 1. 命令来源
-- 1. 服务名称
function command.close(source, svcname)
	return close(svcname)
end

-- 获取指定服务句柄
-- 1. 命令来源
-- 2. 服务名称
function command.query(source, svcname)
	local m = svcmapping[svcname]
	if m ~= nil then
		return m.service
	else
		return nil
	end
end

-- 垃圾回收通知
function command.gc()
	for _, m in pairs(svcmapping) do
		if v.collect then
			skynet.send(v.service, "lua", "collect")
		end
	end
	skynet.send(skynet.self(), "lua", "collect")
end

-- 服务命令转发
-- 1. 命令来源
-- 2. 服务名称
-- 3. 命令名称
-- 4. 命令参数
function command.send(source, svcname, cmd, ...)
	local service = (svcmapping[svcname] or {}).service
	if service then
		skynet.send(service, "lua", cmd, ...)
	else
		ERROR("svcmanager : service[%s] not exists!!!", svcname)
	end
end

-- 服务命令调用
-- 1. 命令来源
-- 2. 服务名称
-- 3. 命令名称
-- 4. 命令参数
function command.call(source, svcname, cmd, ...)
	local service = (svcmapping[svcname] or {}).service
	if service then
		local ok, retval = skynet.call(service, "lua", cmd, ...)
		if ok ~= 0 then
			ERROR(ok, "svcmanager : %s.call() failed", svcname)
		else
			return retval
		end
	else
		ERROR("svcmanager : service[%s] not exists!!!", svcname)
	end
end

-----------------------------------------------------------
--- 底层通知回调
-----------------------------------------------------------
local handler = {}

-- 服务开启通知
-- 1. 启动配置
function handler.init_handler(configure)
end

-- 服务退出通知
function handler.exit_handler()
	for _, svcname in pairs(svcordinal) do
		pcall(function()
			close(svcname)
		end)
	end
	svcmapping = {}
	svcordinal = {}
end

-- 服务启动通知
function handler.start_handler()
end

-- 服务停止通知
function handler.stop_handler()
end

-- 消息分发逻辑
-- 1. 消息来源
-- 2. 消息类型
-- 3. 消息内容
function handler.command_handler(source, cmd, ...)
	local fn = command[cmd]
	if fn then
		return fn(source, ...)
	else
		ERROR("svcmanager : command[%s] can't find!!!", cmd)
	end
end

-- 启动服务管理器
service.start(handler)
