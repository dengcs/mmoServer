---------------------------------------------------------------------
--- 角色信息存储逻辑
---------------------------------------------------------------------
local skynet = require "skynet"
local mysqlaux = require "skynet.mysqlaux.c"

local M = {}

-- 数据查询操作
-- 1. 数据键值
function M.get(key)
	local sql = string.format("SELECT vdata FROM player_tbl WHERE uid = %s", key)
	local ok,data = skynet.call(GLOBAL.SERVICE_NAME.DATABASED, "lua", "get", "test", sql)
	
    if ok ~= 0 then
        ERROR("'%s[%s]' execute failed['%s']!!!", "test", key, data)
    end
    if data and data.errno then
        ERROR("'%s[%s]' execute failed['%s']!!!", "test", key, data.errno)
    end
    
    if next(data) then
    	return data[1].vdata
    end
end

-- 数据更新操作
-- 1. 数据键值
-- 2. 数据内容
function M.set(key, value)
	local vdata = mysqlaux.quote_sql_str(value)
	local sql = string.format("UPDATE player_tbl SET vdata = %s WHERE uid = %s", vdata, key)
	local ok,data = skynet.call(GLOBAL.SERVICE_NAME.DATABASED, "lua", "set", "test", sql)
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
function M.del(db, key)
	ERROR("this function isn't implemented!!!")
end

-- 判断键值是否有效
-- 1. 数据库名称
-- 2. 数据键值
function M.exists(db, key)
	ERROR("this function isn't implemented!!!")
end

-- 返回用户基本信息存储逻辑
return M
