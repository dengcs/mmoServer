local skynet        = require "skynet"
local random        = require "utils.random"

local tb_insert = table.insert
local tb_remove = table.remove

local min_count = 5
local max_count = 10
local agent_pool = {}

function agent_pool.new()
    local pool = {queue = {}}
    return setmetatable(pool, {__index = agent_pool})
end

function agent_pool:init(count)
    local max_add = max_count - #self.queue
    local add_count = math.min((count or max_count), max_add)
    for i=1, add_count do
        local agent = skynet.newservice("agent")
        skynet.call(agent, "lua", "init")
        tb_insert(self.queue, agent)
    end
end

function agent_pool:inc()
    skynet.timeout(0,function()
        local random_count = max_count - min_count
        local count = random.Get(random_count)
        self:init(count)
    end)
end

function agent_pool:pop()
    local capacity = #self.queue
    if capacity > 0 then
        if capacity == min_count then
            self:inc()
        end
        return tb_remove(self.queue)
    else
        self:inc()

        local agent = skynet.newservice("agent")
        skynet.call(agent, "lua", "init")
        return agent
    end
end

return agent_pool