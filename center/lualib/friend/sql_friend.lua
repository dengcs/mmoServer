local nova       = require "nova"
local mysqlaux   = require "skynet.mysqlaux.c"
local userdriver = nova.userdriver()
local QUERY      = {}

-- 数据库名称
local database = nova.getenv("db_name") or "AMBER"

-- 查询所有好友数据
function QUERY.on_load_all_friend()
    local sql = "SELECT uid, data FROM friend_storage"
    return userdriver.select(database, sql)
end

-- 加载好友数据
function QUERY.on_load_friend(uid)
    local sql = string.format("SELECT uid, data FROM friend_storage WHERE uid = '%s' ", uid)
    return userdriver.select(database, sql)
end

-- 更新好友数据
function QUERY.on_friend_update(uid , data)
    data = mysqlaux.quote_sql_str(data)
    local sql = string.format("UPDATE friend_storage SET data = %s WHERE uid = '%s' ", data, uid)
    return userdriver.update(database, sql)
end

-- 插入好友数据
function QUERY.on_friend_insert(uid, data)
    data = mysqlaux.quote_sql_str(data)
    local sql = string.format("INSERT friend_storage(uid, data) VALUES('%s',%s) ON DUPLICATE KEY UPDATE data = %s", uid, data, data)
    return userdriver.insert(database, sql)
end

return QUERY
