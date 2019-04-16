local connector = require "persistent.db_connector"
local mongo     = require "skynet.db.mongo"

local mongo_connector = class("MongoConnector", connector)

-- 构建数据库连接对象（设置连接器类型）
function mongo_connector:ctor()
    self.super.ctor(self)
    self.mode = GLOBAL.DB.MONGO
end

-- 建立数据库连接
-- 1. 数据源地址
-- 2. 数据源端口
-- 3. 数据库名称
-- 4. 用户账号
-- 5. 用户密码
function mongo_connector:connect(host, port, database, auth, pwd)
    -- 建立数据库连接（底层连接）
    local connect = mongo.client({
        host            = host,
        port            = port,
        username        = auth,
        password        = pwd,
    })
    if not connect then
        return ENETUNREACH
    end
    -- 记录底层连接句柄
    self.connect = connect[database]

    if not self.connect then
        return ECONNABORTED
    end

    -- 回调通知连接建立
    if self.handler.connect_handler then
        self.handler:connect_handler(self)
    end
    return 0
end

-- 关闭数据库连接
function mongo_connector:disconnect()
    -- 确定底层连接存在
    local connect = self.connect
    if not connect then
        LOG_ERROR("illegal connection on mysql lib.")
        return
    end
    --  回调通知连接关闭
    if self.handler.disconnect_handler then
        self.handler:disconnect_handler(self)
    end
    -- 关闭数据库连接（底层连接）
    self.connect:disconnect()
    self.connect = nil
end

-- 获取指定数据
-- 1. SQL语句
function mongo_connector:get(collection, key)
    return self.connect[collection]:findOne(key)
end

-- 更新指定数据
-- 1. SQL语句
-- 2. 无效内容
function mongo_connector:set(collection, key, value)
    local update = {['$set'] = value}
    return self.connect[collection]:update(key, update, true)
end

-- 删除指定数据
-- 1. SQL语句
function mongo_connector:del(collection, key)
    return self.connect[collection]:delete(key)
end

-- 判断指定数据是否存在
-- 1. SQL语句
function mongo_connector:exists(collection, key)
    return self.connect[collection]:find(key):count() > 0
end

-- 列出全部键值
function mongo_connector:keys(collection, key)
    local result = {}
    local cursor = self.connect[collection]:find(key)
    if cursor then
        while cursor:hasNext() do
            table.insert(result, cursor:next())
        end
    end
    return result
end

-- 插入数据
function mongo_connector:insert(collection, value)
    return self.connect[collection]:safe_insert(value)
end

return mongo_connector
