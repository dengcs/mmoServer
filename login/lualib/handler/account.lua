---------------------------------------------------------------------
--- 登录相关业务逻辑（'登录主服务/登录子服务'均导出以下接口）
---------------------------------------------------------------------
local skynet   = require "skynet"

---------------------------------------------------------------------
--- 服务回调接口
---------------------------------------------------------------------
local COMMAND = {}

-- 冻结指定用户（仅限GM调用）
-- 1. 用户编号
function COMMAND:freeze(uid)
end

-- 解冻指定用户（仅限GM调用）
-- 1. 用户编号
function COMMAND:unfreeze(uid)
end

-----------------------------------------------------------
--- 网络请求接口
-----------------------------------------------------------
local REQUEST = {}

-- 用户登录请求
function REQUEST:account_login()
  local account = self.proto.account
  local passwd = self.proto.passwd
  skynet.error("dcs--account--"..account..","..passwd)
  skynet.send(GLOBAL.SERVICE_NAME.HANDSHAKE,"lua","sign",account)

	return 0
end

-- '请求/命令'导出
return { REQUEST = REQUEST, COMMAND = COMMAND }
