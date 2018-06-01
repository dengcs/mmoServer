-----------------------------------------------------------
--- 游戏服登录逻辑
-----------------------------------------------------------
local skynet     = require "skynet"

local HANDLER    = {}
local PREPARE    = {}
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
function PREPARE:query_players()
	
end

-- 请求创建角色（选角状态，创角成功则转为正常游戏状态）
function PREPARE:create_player()
	
end

-- 选择指定角色（选角状态，选角成功则转为正常游戏状态）
function PREPARE:choice_player()
	
end

HANDLER.PREPARE   = PREPARE
HANDLER.HANDSHAKE = HANDSHAKE
return HANDLER
