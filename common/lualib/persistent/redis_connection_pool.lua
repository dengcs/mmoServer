local connection_pool = require "persistent.db_connection_pool"
local redis_connector = require "persistent.redis_connector"

local redis_connection_pool = class("RedisConnectionPool", connection_pool)

-- 创建数据库连接池
function redis_connection_pool:ctor()
    self.super.ctor(self)
    self.mode = GLOBAL.DB.REDIS
end

-- 启动数据库连接池
function redis_connection_pool:start(conf)
    self.super.start(self, conf)
    -- 最大连接数量
    local max = self.max_client
    -- 添加数据库连接到连接池
    local r = nil
    for n = 1, max do
        local inst = redis_connector.new()
        -- 注册通知回调接口
        inst:register_handler(self)
        -- 连接数据库
        local result = inst:connect(self.host, self.port, self.database, self.auth)
        if result > 0 then
            LOG_ERROR("redis: start: connect '%s@%s:%d' invalid", self.auth, self.host, self.port)
            r = result
        end
    end
    return r
end

-- 停止数据库连接池
function redis_connection_pool:stop()
    self.super.stop(self)
end

-- 连接成功后触发（连接池会记录数据库连接）
function redis_connection_pool:connect_handler(inst)
    self.super.connect_handler(self, inst)
end

-- 连接断开后触发（连接池会移除数据库连接）
function redis_connection_pool:disconnect_handler(inst)
    self.super.disconnect_handler(self, inst)
end

return redis_connection_pool
