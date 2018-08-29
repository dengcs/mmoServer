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

--分配序列号
local seq = 0
local sub_seq = 0

function COMMAND:on_gen_seq()
	local now = os.time()
	local ret = now
	if ret == seq then
		sub_seq = sub_seq + 1
		ret = ret * 1000 + sub_seq
		if sub_seq >= 999 then
			sub_seq = 0
		end
	else
		ret = ret * 1000
	end
	seq = now
	return ret
end

-- '请求/命令' : 注册
HANDLER.REQUEST = REQUEST
HANDLER.CMD     = COMMAND
return HANDLER
