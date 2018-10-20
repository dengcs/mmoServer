---------------------------------------------------------------------
--- 角色信息存储逻辑
---------------------------------------------------------------------
local skynet = require "skynet"


local M = {}

local db = GAME.META.PLAYER

-- 键值构造逻辑
local function kgen(key)
	return string.format("player:%s", key)
end

-- 数据查询操作
-- 1. 数据库名称
-- 2. 数据键值
function M.get(key)
    
    local ok,data = skynet.call(GLOBAL.SERVICE_NAME.DATACACHED, "lua", "get", db, kgen(key))
    
    if ok ~= 0 then
        ERROR("'%s[%s]' execute failed['%s']!!!", "test", key, data)
    end
    
    if data and data.errno then
        ERROR("'%s[%s]' execute failed['%s']!!!", "test", key, data.errno)
    end
    
    return data
end

-- 数据更新操作
-- 1. 数据库名称
-- 2. 数据键值
-- 3. 数据内容
function M.set(key, value)
	local ok,data = skynet.call(GLOBAL.SERVICE_NAME.DATACACHED, "lua", "set", db, kgen(key), value)
	if ok ~= 0 then
        ERROR("'%s[%s]' execute failed['%s']!!!", "test", key, data)
    end
    
    if data and data.errno then
        ERROR("'%s[%s]' execute failed['%s']!!!", "test", key, data.errno)
    end
    
	return data
end

-- 数据删除操作
-- 1. 数据库名称
-- 2. 数据键值
function M.del(key)
	ERROR("this function isn't implemented!!!")
end

-- 判断键值是否有效
-- 1. 数据库名称
-- 2. 数据键值
function M.exists(key)
	ERROR("this function isn't implemented!!!")
end

-- 返回用户基本信息存储逻辑
return M
