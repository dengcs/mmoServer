-----------------------------------------------------------
--- 游戏服登录逻辑
-----------------------------------------------------------
local skynet  	= require "skynet"
local random	= require "utils.random"


local HANDLER		= {}
local PREPARE 		= {}
local HANDSHAKE 	= {}
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

-- 请求注册
function PREPARE:register()
	local resp = "account_login_resp"

	local token = random.Get(100000000)

	local ret = this.call("set_token", token)

	self.response(resp, {ret = ret, token = token})
end

-- 验证
function HANDSHAKE:verify()
	local resp = "account_login_resp"

	local token = self.proto.token

	local ret = this.call("verify_token", token)

	self.response(resp, {ret = ret})
end

HANDLER.PREPARE   	= PREPARE
HANDLER.REQUEST   	= REQUEST
HANDLER.HANDSHAKE	= HANDSHAKE
return HANDLER
