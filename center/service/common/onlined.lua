---------------------------------------------------------------------
--- 角色在线管理服务（区服公共服务）
---------------------------------------------------------------------
local service = require "factory.service"
local skynet  = require "skynet.manager"
local cluster = require "skynet.cluster"
local json    = require "cjson"
local timer   = require "utils.timer"

---------------------------------------------------------------------
--- 内部变量/内部逻辑
---------------------------------------------------------------------

-- 在线角色集合（角色编号索引）
local onlines = {}

-- 定时任务（定时统计在线人数）
local function schedule()
	-- 任务逻辑
	local function fn()
		-- 渠道分组统计
		local channels = {}
		local ucount   = 0
		for _, u in pairs(onlines) do
			local k = u.snapshot.channel
			local m = channels[k]
			if m == nil then
				m = { channel = k, count = 0 }
				channels[k] = m
			end
			ucount  = ucount  + 1
			m.count = m.count + 1
		end
		-- 提交统计信息
		for _, v in pairs(channels) do
			-- 基础实时日志
			local record = 
			{
				EventID     = "PlayerOnline",
				EventTime   = os.time(),
				ZoneID      = skynet.getenv("zoneid") or 0,
				GameSvrId   = skynet.getenv("zoneid") or 0,
				PlatID      = "",
				Channel     = v.channel,
				Count       = v.count,
			}
			LOG_RECORD(json.encode(record))
			-- '英雄互娱'实时统计
			skynet.send(GAME.SERVICE.BDC.METRICS, "lua", "realtime", "ONLINE", {channel = v.channel, onlines = v.count})
		end
	end
	-- 异常处理
	local function catch(message)
		LOG_ERROR(message)
	end
	-- 间隔时间
	local function interval()
		return timer.get_next_cron_min_point(5) - os.time()
	end
	-- 任务处理
	xpcall(fn, catch)
	this.schedule(schedule, interval(), 0)
end

---------------------------------------------------------------------
--- 服务导出接口
---------------------------------------------------------------------
local COMMAND = {}

-- 服务启动通知
-- 1. 启动参数
function COMMAND.on_init(arguments)
	schedule()
end

-- 服务退出通知
-- 1. 退出参数
function COMMAND.on_exit(arguments)
end

-- 用户上线通知
-- 1. 节点名称
-- 2. 角色编号
-- 3. 角色信息
function COMMAND.on_login(nodename, pid, snapshot)
	assert(nodename)
	assert(pid)
	onlines[pid] =
	{
		nodename = nodename,
		snapshot = snapshot,
	}
	return 0
end

-- 用户离线通知
-- 1. 节点名称
-- 2. 角色编号
function COMMAND.on_logout(nodename, pid)
	assert(nodename)
	assert(pid)
	local u = onlines[pid]
	if u then
		assert(u.nodename == nodename)
		onlines[pid] = nil
	end
	return 0
end

-- 在线用户列表
function COMMAND.onlines()
	local keys = {}
	for pid, _ in pairs(onlines) do
		table.insert(keys, pid)
	end
	return keys
end

-- 在线状态列表
function COMMAND.onlines_status()
	local status = {}
	for pid, _ in pairs(onlines) do
		status[pid] = true
	end
	return status
end

-- 调用角色命令
-- 1. 角色编号
-- 2. 命令名称
-- 3. 命令参数
function COMMAND.usercall(pid, cmd, ...)
	local u = onlines[pid]
	if u then
		return cluster.call(u.nodename, GLOBAL.SERVICE_NAME.USERCENTERD, "usercall", pid, cmd, ...)
	else
		ERROR("onlined.usercall(%s) : user[%s] not exists!!!", cmd, pid)
	end
end

-- 触发角色命令
-- 1. 角色编号
-- 2. 命令名称
-- 3. 命令内容
function COMMAND.usersend(pid, cmd, ...)
	local u = onlines[pid]
	if u then
		cluster.send(u.nodename, GLOBAL.SERVICE_NAME.USERCENTERD, "usersend", pid, cmd, ...)
	end
end

-- 在线用户通知（事件触发）
-- 1. 命令名称
-- 2. 命令内容
function COMMAND.notice(cmd, ...)
	for pid, u in pairs(onlines) do
		clustrer.send(u.nodename, GLOBAL.SERVICE_NAME.USERCENTERD, "usersend", uid, cmd, ...)
	end
end

-- 在线用户通知（消息广播）
-- 1. 消息名称
-- 2. 消息内容
function COMMAND.broadcast(name, data)
	for uid, u in pairs(onlines) do
		pcall(function()
			cluster.send(u.nodename, GLOBAL.SERVICE_NAME.USERCENTERD, "usersend", uid, "response", name, data)
		end)
	end
	return 0
end

---------------------------------------------------------------------
--- 注册在线管理服务
---------------------------------------------------------------------

local handler = {}

-- 消息分发逻辑
-- 1. 消息来源
-- 2. 消息类型
-- 3. 消息内容
function handler.command_handler(source, cmd, ...)
	local fn = COMMAND[cmd]
	if fn then
		return fn(...)
	else
		ERROR("svcmanager : command[%s] can't find!!!", cmd)
	end
end

handler.init_handler = init_handler
handler.exit_handler = exit_handler

service.start(handler)