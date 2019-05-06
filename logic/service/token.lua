---------------------------------------------------------------------
--- 令牌管理服务
---------------------------------------------------------------------
local service   = require "factory.service"
local random    = require "utils.random"

local tokens = {}

local base_token = nil

---------------------------------------------------------------------
--- 服务导出接口
---------------------------------------------------------------------
local COMMAND = {}

-- 生成令牌
function COMMAND.generate(source, account)
    if not base_token then
        base_token = random.Get(100000000)
    end

    if not tokens[account] then
        local token = base_token + 1
        tokens[account] = token
    end

    return tokens[account]
end

-- 清理令牌
function COMMAND.clear(source, account)
    tokens[account] = nil
end

-- 获取令牌
function COMMAND.get(source, account)
    return tokens[account]
end

---------------------------------------------------------------------
--- 服务事件回调（底层事件通知）
---------------------------------------------------------------------
local server = {}

-- 内部命令分发
-- 1. 命令来源
-- 2. 命令名称
-- 3. 命令参数
function server.command_handler(source, cmd, ...)
    local fn = COMMAND[cmd]
    if fn then
        return fn(source, ...)
    else
        ERROR("command[%s] not found!!!", cmd)
    end
end

-- 启动用户管理服务
service.start(server)