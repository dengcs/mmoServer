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
nova.register_service {
	-- 广播类型
	theme = GLOBAL.PROTO_TYPE.TERMINAL,
	-- 依赖的服务
	require = {},
	-- 垃圾回收
	collect = "true",
	-- 命令集合
	CMD = CMD,
    init_handler = init_handler,
}
