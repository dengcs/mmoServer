-----------------------------------------------------------
--- 游戏服登录逻辑
-----------------------------------------------------------
local skynet  	= require "skynet"
local random	= require "utils.random"


local HANDLER		= {}
local REQUEST 		= {}

-----------------------------------------------------------
--- 内部变量/内部逻辑
-----------------------------------------------------------

-----------------------------------------------------------
--- 网络请求接口
-----------------------------------------------------------
-- 请求断开连接
function REQUEST:disconnect()
	skynet.send(skynet.self(), "lua", "disconnect")
end

-- 请求登陆
function REQUEST:token()
	local resp = "account_login_resp"

	local token = random.Get(100000000)

	self.response(resp, {ret = 0, token = token})
end

HANDLER.REQUEST   	= REQUEST
return HANDLER
