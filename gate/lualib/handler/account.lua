---------------------------------------------------------------------
--- 登录相关业务逻辑（'登录主服务/登录子服务'均导出以下接口）
---------------------------------------------------------------------
local skynet   = require "skynet"

local dbname = "test"

---------------------------------------------------------------------
--- 内部函数
---------------------------------------------------------------------

local function check_account(account)
	local sql = string.format("SELECT pid, state FROM account WHERE account = '%s'", account)
	local ret = userdriver.select(dbname, sql)
end

local function add_account(account)
end

---------------------------------------------------------------------
--- 服务回调接口
---------------------------------------------------------------------
local COMMAND = {}

-- 冻结指定用户（仅限GM调用）
-- 1. 用户编号
function COMMAND:freeze(pid)
end

-- 解冻指定用户（仅限GM调用）
-- 1. 用户编号
function COMMAND:unfreeze(pid)
end

-----------------------------------------------------------
--- 网络请求接口
-----------------------------------------------------------
local REQUEST = {}

-- 用户登录请求
function REQUEST:account_login()
	local account = self.proto.account
	local passwd = "12345678"
	skynet.error("dcs--account--"..account)
	local ok,token = skynet.call(GLOBAL.SERVICE_NAME.HANDSHAKE,"lua","sign",account)
	
	local ret_msg = {ret = ok, token = token}
    self.response("account_login_resp", ret_msg)
	return 0
end

-- '请求/命令'导出
return { REQUEST = REQUEST, COMMAND = COMMAND }
