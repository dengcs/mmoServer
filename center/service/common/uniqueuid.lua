local service = require "service"
local nova    = require "nova"

local serverid
local incrby = 0
local lastostime = 0
local incrtime = 0

local CMD = {}

-----------------------------------------------------------
-- 系统通知
-----------------------------------------------------------

local function init_handler()
	serverid = nova.getenv("nodeid") or 100
end

-----------------------------------------------------------
-- 服务逻辑
-----------------------------------------------------------

-- 分配唯一编号
function CMD.allocuid()
	--		 5char+ |10char|6char
	--uid = serverid|ostime|incrby
	--理论上每秒支持分配2^16个uid
	--当前系统时间，秒级
	local ostime = os.time()
	incrby = incrby + 1
	if incrby >= 0xffff then
		incrby = 1
		incrtime = incrtime + 1
		lastostime = ostime
	end
	if incrtime > 0 and ostime - lastostime > incrtime then
		incrtime = 0
	else
		ostime = ostime + incrtime
	end
	local uid = serverid .. string.format("%010d", ostime) .. string.format("%06d",incrby)
	--skynet.error("succ alloc uid: " ..uid)
	return uid
end

local global_service_id = 0
-- 分配服务编号
function CMD.allocsid()
	global_service_id = global_service_id + 1
	if global_service_id > 99999999 then
		global_service_id = 1
	end
	return global_service_id
end


-- 注册服务

local handler = {}

-- 消息分发逻辑
-- 1. 消息来源
-- 2. 消息类型
-- 3. 消息内容
function handler.command_handler(source, cmd, ...)
	local fn = CMD[cmd]
	if fn then
		return fn(source, ...)
	else
		ERROR("svcmanager : command[%s] can't find!!!", cmd)
	end
end

handler.init_handler = init_handler
handler.exit_handler = exit_handler

service.start(handler)