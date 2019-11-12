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
	local ret = 0

	local pid = tonumber(self.proto.pid)

    repeat
        local ok, result = skynet.call(GLOBAL.SERVICE_NAME.USERCENTER, "lua", "verify_fd", pid, self.client_fd)
        if ok ~= 0 or result == false then
            ret = ERRCODE.COMMON_PARAMS_ERROR
            break
        end

        local code = skynet.call(GLOBAL.SERVICE_NAME.USERCENTER, "lua", "load", pid)
        if code ~= 0 then
            ret = ERRCODE.COMMON_SYSTEM_ERROR
            break
        end
        this.call("load_data", pid)
    until(true)
    local ret_msg = {ret = ret}
    self.response(resp, ret_msg)
end

HANDLER.REQUEST   	= REQUEST
return HANDLER
