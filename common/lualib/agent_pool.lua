local skynet        = require "skynet"

local tb_insert = table.insert
local tb_remove = table.remove

local max_count = 10
local need_add = false
local agent_pool = {}

function agent_pool.new()
    local pool = {agent_queue = {}}

    setmetatable(pool, {__index = agent_pool})

    return pool
end

function agent_pool:inc()
    skynet.fork(function()
        local capacity = #self.agent_queue
        if capacity >= max_count then
            need_add = false
            return
        end

        local agent = skynet.newservice("agentd")
        skynet.call(agent, "lua", "init")
        tb_insert(self.agent_queue, agent)
    end)
end

function agent_pool:pop()
    local capacity = #self.agent_queue
    if capacity > 0 then
        if need_add then
            self:inc()
        end
        local agent = tb_remove(self.agent_queue)
        return agent
    else
        need_add = true
        self:inc()

        local agent = skynet.newservice("agentd")
        skynet.call(agent, "lua", "init")
        return agent
    end
end

return agent_pool