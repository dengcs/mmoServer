-----------------------------------------------------------
--- 游戏服登录逻辑
-----------------------------------------------------------
local skynet  	= require "skynet"


local HANDLER		= {}
local REQUEST 		= {}
local COMMAND		= {}

-----------------------------------------------------------
--- 内部变量/内部逻辑
-----------------------------------------------------------
local data = {}

-----------------------------------------------------------
--- 网络请求接口
-----------------------------------------------------------

-- 登录
function REQUEST:game_login()
	local resp = "game_login_resp"

	local pid = tonumber(self.proto.pid)

	this.call("load_data", pid)

    local ret_msg = {ret = 0}
    self.response(resp, ret_msg)
end

-----------------------------------------------------------
--- 命令接口
-----------------------------------------------------------

HANDLER.REQUEST   	= REQUEST
HANDLER.COMMAND 	= COMMAND
return HANDLER
