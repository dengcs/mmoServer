local skynet        = require "skynet"

local max_count = 60
local inc_count = 6
local need_add = false
local agent_pool = {}

function agent_pool.new()
    local pool = {capacity = 0,agent_queue = {}}

    setmetatable(pool, {__index = agent_pool})

    return pool
end

function agent_pool:push(agent)
    if self.capacity < max_count then
        if not self.agent_queue[agent] then
            self.agent_queue[agent] = agent
            self.capacity = self.capacity + 1
            return true
        end
    end
    return false
end

function agent_pool:inc(count)
    skynet.fork(function()
        for i=1, count do
            local agent = skynet.newservice("agentd")
            self:push(agent)

            if self.capacity >= max_count then
                need_add = false
                break
            end
        end
    end)
end

function agent_pool:pop()
    if self.capacity > 0 then
        if need_add then
            self:inc(inc_count)
        end
        local agent,_ = next(self.agent_queue)
        if agent then
            self.agent_queue[agent] = nil
            self.capacity = self.capacity - 1
            return agent
        end
    else
        need_add = true
        self:inc(inc_count)

        local agent = skynet.newservice("agentd")
        return agent
    end
end

return agent_pool