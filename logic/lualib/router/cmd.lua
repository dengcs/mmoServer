---------------------------------------------------------------------
--- 区服控制后台服务
---------------------------------------------------------------------
local skynet  = require "skynet"
local md5     = require "md5"
local json    = require "cjson"
local router  = require "router"

---------------------------------------------------------------------
--- 内部变量/内部逻辑
---------------------------------------------------------------------

-- 消息解码逻辑
-- 1. 消息内容
local function decode(vdata)
  if vdata == "" then
    return {}
  end
    -- 消息转换逻辑
    local function convert(tbl)
        for k, v in pairs(tbl) do
            -- 禁止浮点数值
            if type(v) == "number" then
                tbl[k] = math.floor(v)
            end
            -- 消息递归转换
            if type(v) == "table" then
                tbl[k] = convert(v)
            end
        end
        return tbl
    end
    -- 开始消息解码
    return convert(json.decode(vdata))
end

---------------------------------------------------------------------
--- 命令路由逻辑
---------------------------------------------------------------------

-- 请求前置处理（全体命令的前置处理逻辑）
-- 1. 请求对象
-- 2. 应答对象
function router.before_handler(req, res)
	if req.body then
		req.body = decode(req.body)
	else
		ERROR("req.body is nil!!!")
	end
end

-- 请求错误处理
-- 1. 错误描述
function router.error_handler(msg, req, res)
	res.json({code = 1, msg = msg})
end

router.post("/test", function(req, res)	
	res.json({code = 0})
end)

router.get("/test", function(req, res) 
  res.json({code = 0})
end)