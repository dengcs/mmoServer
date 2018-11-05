local capacity = 60

local agent_manager = {}

function agent_manager.new()
    local manager = {capacity = 0,agent_queue = {}}

    setmetatable(manager, {__index = agent_manager})

    return manager
end

function agent_manager:push(agent)
    if self.capacity < capacity then
        if not self.agent_queue[agent] then
            self.agent_queue[agent] = agent
            self.capacity = self.capacity + 1
            return true
        end
    end
    return false
end

function agent_manager:pop()
    if self.capacity > 0 then
        local agent,_ = next(self.agent_queue)
        if agent then
            self.agent_queue[agent] = nil
            self.capacity = self.capacity - 1
            return agent
        end
    end
end

return agent_manager