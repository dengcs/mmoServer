---------------------------------------------------------------------
--- 游戏日志记录服务
---------------------------------------------------------------------
local service = require "service"
local skynet  = require "skynet"

---------------------------------------------------------------------
--- 内部变量/内部逻辑
---------------------------------------------------------------------

-- 日志文件路径
local filepath = skynet.getenv("recfile") or "./log/record/record.log"

-- 日志文件句柄
local vhandler = nil

-- 日志文件滚动
local function roll()
    if vhandler then
        vhandler:close()
    end
    vhandler = io.open(filepath, "a+")
end

---------------------------------------------------------------------
--- 服务导出接口
---------------------------------------------------------------------
local COMMAND = {}

-- 日志滚动命令
function COMMAND.roll()
    roll()
    return 0
end

-- 写入日志内容
-- 1. 日志内容
function COMMAND.write(message)
    if vhandler then
        vhandler:write(message .. "\n")
        vhandler:flush()
    end
    return 0
end

---------------------------------------------------------------------
--- 注册日志记录服务
---------------------------------------------------------------------
local handler = {}

-- 消息分发逻辑
-- 1. 消息来源
-- 2. 消息类型
-- 3. 消息内容
function handler.command_handler(source, cmd, ...)
	local fn = COMMAND[cmd]
	if fn then
		return fn(...)
	else
		ERROR("svcmanager : command[%s] can't find!!!", cmd)
	end
end

function handler.init_handler()
	roll()
end

function handler.exit_handler()
	if vhandler then
        vhandler:close()
    end
end

service.start(handler)