local nova       = require "nova"
local mysqlaux   = require "skynet.mysqlaux.c"
local userdriver = nova.userdriver()
local QUERY      = {}

-- 数据库名称
local database = nova.getenv("db_name") or "AMBER"

-- 查询所有社交数据
function QUERY.on_load_all_social()
    local sql = "SELECT uid, data FROM social_storage"
    return userdriver.select(database, sql)
end

-- 查询社交数据
function QUERY.on_load_social(uid)
    local sql = string.format("SELECT uid, data FROM social_storage WHERE uid = '%s' ", uid)
    return userdriver.select(database, sql)
end

-- 更新社交数据
function QUERY.on_social_update(uid , data)
    data = mysqlaux.quote_sql_str(data)
    local sql = string.format("UPDATE social_storage SET data = %s WHERE uid = '%s' ", data, uid)
    return userdriver.update(database, sql)
end

-- 插入社交数据
function QUERY.on_social_insert(uid, data)
    data = mysqlaux.quote_sql_str(data)
    local sql = string.format("INSERT social_storage(uid, data) VALUES('%s',%s) ON DUPLICATE KEY UPDATE data = %s", uid, data, data)
    return userdriver.insert(database, sql)
end

return QUERY
