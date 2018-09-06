local skynet  = require "skynet"

local dbname = "test"

local DBToSQL = 
{
	[GAME.META.PLAYER] = "SELECT vdata FROM player_tbl WHERE uid=%s"
}

local function getSql(db, key)
	local sql_statement = string.format(DBToSQL[db],key)
	print("dcs--sql--"..sql_statement)
	return sql_statement
end

local Proxy = {}

-- 数据集查询操作（仅仅访问'redis'数据源）
-- 1. 数据源
-- 2. 关键字
function Proxy.get(db, key)
    local ok,result = skynet.call(GLOBAL.SERVICE_NAME.DATACACHED, "lua", "get", db, key)
    
    if ok ~= 0 or not result then
    	ok,result = skynet.call(GLOBAL.SERVICE_NAME.DATABASED, "lua", "get", dbname, getSql(db, key))
    	if ok ~= 0 or not result then
    		return nil
    	end
    end
    
    return result
end

-- '插入/更新'数据操作
-- 1. 数据源
-- 2. 关键字
-- 3. 数据内容
function Proxy.set(db, key, value)
    local ok,result = skynet.call(GLOBAL.SERVICE_NAME.DATACACHED, "lua", "set", db, key)
    
    if ok ~= 0 then
		return nil
    end
    
    skynet.call(GLOBAL.SERVICE_NAME.DATABASED, "lua", "set", dbname, key)
    
    return result
end

-- 删除指定数据（一般不会使用）
-- 1. 数据源
-- 2. 关键字
function Proxy.del(source, db, key)
end

-- 判断'redis'中是否存在指定数据
-- 1. 数据源
-- 2. 关键字
function Proxy.exists(source, db, key)
    local ok,result = skynet.call(GLOBAL.SERVICE_NAME.DATACACHED, "lua", "exists", db, key)
    
    if ok ~= 0 or not result then
    	ok,result = skynet.call(GLOBAL.SERVICE_NAME.DATABASED, "lua", "exists", dbname, key)
    	if ok ~= 0 or not result then
    		return nil
    	end
    end
    
    return result
end


function Proxy.keys(source, db, key)
    local ok,result = skynet.call(GLOBAL.SERVICE_NAME.DATACACHED, "lua", "keys", db, key)
    
    if ok ~= 0 or not result then
    	ok,result = skynet.call(GLOBAL.SERVICE_NAME.DATABASED, "lua", "keys", dbname, key)
    	if ok ~= 0 or not result then
    		return nil
    	end
    end
    
    return result
end

return Proxy