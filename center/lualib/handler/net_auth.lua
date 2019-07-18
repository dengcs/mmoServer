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


-- 登录
function REQUEST:game_login()
	local resp = "game_login_resp"
	local ret = ERRCODE.COMMON_SYSTEM_ERROR

	local pid = tonumber(self.proto.pid)

	this.call("load_data", pid)
	
	local ok = skynet.call(GLOBAL.SERVICE_NAME.USERCENTERD, "lua", "load", pid)
	if ok ~= 0 then
		ret = ERRCODE.COMMON_SYSTEM_ERROR
	end
    local ret_msg = {ret = ret}
    self.response(resp, ret_msg)
end

HANDLER.REQUEST   	= REQUEST
return HANDLER
