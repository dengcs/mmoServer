local skynet  = require "skynet"

local DB_MAP = 
{
	cache = {
		[GAME.META.PLAYER] = "db.redis.player"
	},
	base = {
		[GAME.META.PLAYER] = "db.mysql.player"
	}
}

local Proxy = {}

-- 数据集查询操作（仅仅访问'redis'数据源）
-- 1. 数据源
-- 2. 关键字
function Proxy.get(db, key)
    local cacheStatement = require(DB_MAP.cache[db])
    local result = cacheStatement.get(key)
    if not result then
    	local baseStatement = require(DB_MAP.base[db])
    	result = baseStatement.get(key)    	
    end
    
    return result
end

-- '插入/更新'数据操作
-- 1. 数据源
-- 2. 关键字
-- 3. 数据内容
function Proxy.set(db, key, value)
    local cacheStatement = require(DB_MAP.cache[db])
    local result = cacheStatement.set(key, value)
    if not result then
		return nil
    end
    
    local baseStatement = require(DB_MAP.base[db])
	result = baseStatement.set(key, value)
    
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