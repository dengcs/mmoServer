local COLLECTION_MAP =
{
    [GAME.COLLECTIONS.PLAYER] = require("db.mongo.player")
}

local Proxy = {}

-- 数据集查询操作（仅仅访问'redis'数据源）
-- 1. 数据源
-- 2. 关键字
function Proxy.get(tb, key)
    local collection = COLLECTION_MAP[tb]
    local result = collection.get(key)
    return result
end

-- '插入/更新'数据操作
-- 1. 数据源
-- 2. 关键字
-- 3. 数据内容
function Proxy.set(tb, key, value)
    local collection = COLLECTION_MAP[tb]
    local result = collection.set(key, value)
    return result
end

-- 删除指定数据（一般不会使用）
-- 1. 数据源
-- 2. 关键字
function Proxy.del(source, db, key)
	ERROR("this function isn't implemented!!!")
end

-- 判断'redis'中是否存在指定数据
-- 1. 数据源
-- 2. 关键字
function Proxy.exists(source, db, key)
    ERROR("this function isn't implemented!!!")
end


function Proxy.keys(source, db, key)
    ERROR("this function isn't implemented!!!")
end

return Proxy