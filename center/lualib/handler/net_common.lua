--
-- 定义一些模块无关的通用逻辑接口
--
local skynet       = require "skynet"

local HANDLER      = {}
local REQUEST      = {}
local COMMAND      = {}

-- 消息通知
function COMMAND:on_common_notify(name, data)
	self.response(name, data)
end

-- 获取"AGENT"句柄（简化加入服务逻辑）
function COMMAND:on_common_agent()
	return skynet.self()
end

-- '请求/命令' : 注册
HANDLER.REQUEST = REQUEST
HANDLER.COMMAND = COMMAND
return HANDLER
