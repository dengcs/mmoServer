local connection_pool = require "persistent.db_connection_pool"
local mysql_connector = require "persistent.mysql_connector"

local mysql_connection_pool = class("MysqlConnectionPool", connection_pool)

function mysql_connection_pool:ctor()
    self.super.ctor(self)

    self.mode = GLOBAL.DB.MYSQL
end

function mysql_connection_pool:start(conf)
    self.super.start(self, conf)

    local max = self.max_client
    local r = nil
    for n = 1, max do
        local inst = mysql_connector.new()

        inst:register_handler(self)
        local result = inst:connect(self.host, self.port, self.database, self.auth, self.password)
        if result > 0 then
            LOG_ERROR("mysql: start: connect '%s@%s:%d' invalid", self.auth, self.host, self.port)
            r = result
        end
    end

    return r
end

function mysql_connection_pool:stop()
    self.super.stop(self)
end

function mysql_connection_pool:connect_handler(inst)
    self.super.connect_handler(self, inst)
end

function mysql_connection_pool:disconnect_handler(inst)
    self.super.disconnect_handler(self, inst)
end

return mysql_connection_pool
