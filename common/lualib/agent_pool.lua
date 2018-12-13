local skynet        = require "skynet"

local max_count = 10
local need_add = false
local agent_pool = {}

function agent_pool.new()
    local pool = {capacity = 0,agent_queue = {}}

    setmetatable(pool, {__index = agent_pool})

    return pool
end

function agent_pool:push(agent)
    if not self.agent_queue[agent] then
        self.agent_queue[agent] = agent
        self.capacity = self.capacity + 1
    end
end

function agent_pool:inc()
    skynet.fork(function()
        if self.capacity >= max_count then
            need_add = false
            return
        end

        local agent = skynet.newservice("agentd")
        skynet.call(agent, "lua", "init")
        self:push(agent)
    end)
end

function agent_pool:pop()
    if self.capacity > 0 then
        if need_add then
            self:inc()
        end
        local agent,_ = next(self.agent_queue)
        if agent then
            self.agent_queue[agent] = nil
            self.capacity = self.capacity - 1
            return agent
        end
    else
        need_add = true
        self:inc()

        local agent = skynet.newservice("agentd")
        skynet.call(agent, "lua", "init")
        return agent
    end
end

return agent_pool