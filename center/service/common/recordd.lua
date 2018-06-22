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
service.register({
    -- 服务导出接口
    CMD = COMMAND,
    -- 服务启动处理
    init_handler = function()
        roll()
    end,
    -- 服务退出处理
    exit_handler = function()
        if vhandler then
            vhandler:close()
        end
    end,
})
