local connector = require "persistent.db_connector"
local redis = require "skynet.db.redis"

local redis_connector = class("RedisConnector", connector)

-- 构建数据库连接对象（设置连接器类型）
function redis_connector:ctor()
    self.super.ctor(self)
    self.mode = GLOBAL.DB.REDIS
end

-- 建立数据库连接
-- 1. 数据源地址
-- 2. 数据源端口
-- 3. 数据库名称
-- 4. 验证信息
function redis_connector:connect(host, port, db, auth)
    -- 建立数据库连接（底层连接）
    local connect = redis.connect({
        host = host,
        port = port,
        db = db,
        auth = auth,
    })
    if not connect then
        return ECONNREFUSED
    end
    -- 记录底层连接句柄
    self.connect = connect
    -- 回调通知连接建立
    if self.handler.connect_handler then
        self.handler:connect_handler(self)
    end
    return 0
end

-- 关闭数据库连接
function redis_connector:disconnect()
    -- 确定底层连接存在
    local connect = self.connect
    if not connect then
        LOG_ERROR("illegal connection on redis lib.")
        return
    end
    -- 回调通知连接关闭
    if self.handler.disconnect_handler then
        self.handler:disconnect_handler(self)
    end
    -- 关闭数据库连接（底层连接）
    self.connect:disconnect()
    self.connect = nil
end

-- 获取指定数据
function redis_connector:get(key)
    return self.connect:get(key)
end

-- 更新指定数据
function redis_connector:set(key, value)
    return self.connect:set(key, value)
end

-- 删除指定数据
function redis_connector:del(key)
    return self.connect:del(key)
end

-- 判断指定数据是否存在
function redis_connector:exists(key)
    return self.connect:exists(key)
end

-- 列出全部键值
function redis_connector:keys(key)
    return self.connect:keys("*")
end

return redis_connector
