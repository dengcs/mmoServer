local skynet = require "skynet"
local dispatcher = require "net.dispatcher"
local userdata = require "data.userdata"
local usermeta = require "config.usermeta"

local session
-- 网络消息分发器
local net_dispatcher
local datameta      -- 用户数据

local CMD = {}

local function unload()
	if datameta then
		local player = datameta:get("Player")
		if player then
			skynet.call(GLOBAL.SERVICE_NAME.USERCENTERD, "lua", "unload", player.uid)
		end
	end
end

function CMD.connect(source, c)
	session = c
	net_dispatcher = dispatcher.new()
	net_dispatcher:register_handle()
end

function CMD.disconnect()
	unload()

	local ok,ret = skynet.call(GLOBAL.SERVICE_NAME.GATED, "lua", "push_agent", skynet.self())
	if ok~=0 or ret==false then
		skynet.exit()
	end
end

function CMD.open()
	if session then
	  datameta = userdata.new("w")
	  datameta:register(usermeta)
	  
	  session.data = datameta
	end
end

function CMD.close()
	unload()

	local ok,ret = skynet.call(GLOBAL.SERVICE_NAME.GATED, "lua", "push_agent", skynet.self())
	if ok~=0 or ret==false then
		skynet.exit()
	end
end

function CMD.message(source, msg)
  if session then
        net_dispatcher:message_dispatch(session, msg)
  end
end

function CMD.data_set(source, name, data)
	local retval = datameta:init(name, data)
	if not retval then
		ERROR("usermeta:init(name = %s) failed!!!", name)
	end

	local result = retval:copy()

	return result
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
		skynet.error("dcs---cmd--"..cmd)
		local safe_handler = SAFE_HANDLER(session)
		local fn = CMD[cmd]
		if fn then
			return safe_handler(fn, source, ...)
		else
			return safe_handler(command_handler, source, cmd, ...)
		end
	end)
end)
