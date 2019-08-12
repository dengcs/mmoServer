---------------------------------------------------------------------
--- 区服控制后台服务
---------------------------------------------------------------------
local router        = require "router"
local summdriver    = require "driver.summdriver"

---------------------------------------------------------------------
--- 内部变量/内部逻辑
---------------------------------------------------------------------

---------------------------------------------------------------------
--- 命令路由逻辑
---------------------------------------------------------------------

-- 请求前置处理（全体命令的前置处理逻辑）
-- 1. 请求对象
-- 2. 应答对象
function router.before_handler(req, res)
	print("before_handler", table.tostring(req), table.tostring(res))
end

-- 请求错误处理
-- 1. 错误描述
function router.error_handler(msg, req, res)
    print("error_handler", msg, table.tostring(req), table.tostring(res))
end

router.post("/exit", function(req, res)
    require("skynet").error("post---exit")
    summdriver.close()
	res.json({code = 0})
end)

router.get("/exit", function(req, res)
    require("skynet").error("get---exit")
    summdriver.close()
    res.json({code = 0})
end)