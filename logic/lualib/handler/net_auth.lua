-----------------------------------------------------------
--- 游戏服登录逻辑
-----------------------------------------------------------
local skynet     = require "skynet"

local HANDLER    = {}
local REQUEST = {}
local HANDSHAKE  = {}

-----------------------------------------------------------
--- 内部变量/内部逻辑
-----------------------------------------------------------

-----------------------------------------------------------
--- 网络请求接口
-----------------------------------------------------------

-- 握手请求（连接验证）
function HANDSHAKE:handshake()
	
end

-- 请求关联角色（选角状态）
function REQUEST:query_players()
	
end

-- 请求创建角色（选角状态，创角成功则转为正常游戏状态）
function REQUEST:create_player()
    skynet.error("dcs---create_player")
    skynet.call(GLOBAL.SERVICE_NAME.USERCENTERD, "lua", "load", "1001")
    skynet.error("dcs---data--"..table.tostring(self.user))
    local ret_msg = {ret = 1}
    self.response("create_player_resp", ret_msg)
end

-- 选择指定角色（选角状态，选角成功则转为正常游戏状态）
function REQUEST:choice_player()
	
end

HANDLER.REQUEST   = REQUEST
HANDLER.HANDSHAKE = HANDSHAKE
return HANDLER
