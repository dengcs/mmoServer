-----------------------------------------------------------
--- 游戏服登录逻辑
-----------------------------------------------------------
local skynet  	= require "skynet"


local HANDLER		= {}
local REQUEST 		= {}

-----------------------------------------------------------
--- 内部变量/内部逻辑
-----------------------------------------------------------

-----------------------------------------------------------
--- 网络请求接口
-----------------------------------------------------------
-- 断线重连
function REQUEST:connect()
	print("dcs------connect")
end

-- 请求断开连接
function REQUEST:disconnect()
	local pid = self.user.pid
	skynet.send(skynet.self(), "lua", "disconnect")
	skynet.send(GLOBAL.SERVICE_NAME.SOCIAL, "lua", "save", pid)
	skynet.send(GLOBAL.SERVICE_NAME.USERCENTER, "lua", "unload", pid)
end

HANDLER.REQUEST   	= REQUEST
return HANDLER
