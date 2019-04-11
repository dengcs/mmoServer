local skynet        = require "skynet"
local random        = require "utils.random"

local tb_insert = table.insert
local tb_remove = table.remove

local init_count = 3
local agent_pool = {}

function agent_pool.new()
    local pool = {agent_queue = {}}

    setmetatable(pool, {__index = agent_pool})

    return pool
end

function agent_pool:init(count)
    local add_count = count or init_count
    for i=1, add_count do
        local agent = skynet.newservice("agentd")
        skynet.call(agent, "lua", "init")
        tb_insert(self.agent_queue, agent)
    end
end

function agent_pool:inc()
    skynet.fork(function()
        local count = random.Get(init_count)
        self:init(count)
    end)
end

function agent_pool:pop()
    local capacity = #self.agent_queue
    if capacity > 0 then
        if capacity == 1 then
            self:inc()
        end
        local agent = tb_remove(self.agent_queue)
        return agent
    else
        self:inc()

        local agent = skynet.newservice("agentd")
        skynet.call(agent, "lua", "init")
        return agent
    end
end

return agent_pool