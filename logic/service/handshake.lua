local skynet  = require "skynet"
local service = require "service_factory.service"
local random = require "util.random"

local server = {}
local CMD = {}

local tokenMap = {}
local generateId = 1

local function fetch_token()
  local token = generateId
  
  generateId = generateId + 1
  
  return token
end

function CMD.sign(account)
    skynet.error("dcs--"..account)
    local token = fetch_token()
    tokenMap[account] = token
end

function CMD.check(account, token)
    local cur_token = tokenMap[account]
    
    if cur_token then
        if cur_token == token then
            return true
        end
    end
    
    return false
end

function server.init_handler()
    generateId = random.Get(100000)
end

function server.exit_handler()
end

function server.start_handler()

    return 0
end

function server.stop_handler()

    return 0
end

function server.command_handler(source, cmd, ...)
    local f = CMD[cmd]
    if f then
        return f(...)
    else
        ERROR(EFAULT, "call: %s: command not found", cmd)
    end
end

service.start(server)
