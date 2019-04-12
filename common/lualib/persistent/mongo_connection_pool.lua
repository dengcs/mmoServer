local connection_pool = require "persistent.db_connection_pool"
local mongo_connector = require "persistent.mongo_connector"

local mongo_connection_pool = class("MysqlConnectionPool", connection_pool)

function mongo_connection_pool:ctor()
    self.super.ctor(self)

    self.mode = GLOBAL.DB.MONGO
end

function mongo_connection_pool:start(conf)
    self.super.start(self, conf)

    local max = self.max_client
    local r = nil
    for n = 1, max do
        local inst = mongo_connector.new()

        inst:register_handler(self)
        local result = inst:connect(self.host, self.port, self.database, self.auth, self.password)
        if result > 0 then
            LOG_ERROR("mysql: start: connect '%s@%s:%d' invalid", self.auth, self.host, self.port)
            r = result
        end
    end

    return r
end

function mongo_connection_pool:stop()
    self.super.stop(self)
end

function mongo_connection_pool:connect_handler(inst)
    self.super.connect_handler(self, inst)
end

function mongo_connection_pool:disconnect_handler(inst)
    self.super.disconnect_handler(self, inst)
end

return mongo_connection_pool
