---------------------------------------------------------------------
--- 角色信息存储逻辑
---------------------------------------------------------------------
local skynet = require "skynet"

local dbName = "poker"
local dtName = "player"

local M = {}

-- 数据查询操作
-- 1. 数据键值
function M.get(key)
	local query = {pid = key}
	local ok,ret = skynet.call(GLOBAL.SERVICE_NAME.DATAMONGOD, "lua", "get", dbName, dtName, query)
	
    if ok ~= 0 then
        ERROR("'%s[%s]' execute failed['%s']!!!", dbName, dtName, key)
    end
    if ret and ret.errno then
        ERROR("'%s[%s]' execute failed['%s']!!!", dbName, dtName, key)
    end
    
    return ret
end

-- 数据更新操作
-- 1. 数据键值
-- 2. 数据内容
function M.set(key, value)
    local query = {pid = key}
	local ok,ret = skynet.call(GLOBAL.SERVICE_NAME.DATAMONGOD, "lua", "set", dbName, dtName, query, value)
    if ok ~= 0 then
        ERROR("'%s[%s]' execute failed['%s']!!!", dbName, dtName, key)
    end
    if ret and ret.errno then
        ERROR("'%s[%s]' execute failed['%s']!!!", dbName, dtName, key)
    end
    
    return ret
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

function M.keys(key)
    local ok,ret = skynet.call(GLOBAL.SERVICE_NAME.DATAMONGOD, "lua", "keys", dbName, dtName, key)

    if ok ~= 0 then
        ERROR("'%s[%s]' execute failed['%s']!!!", dbName, dtName, table.tostring(key))
    end

    return ret
end

function M.insert(value)
    local ok, ret = skynet.call(GLOBAL.SERVICE_NAME.DATAMONGOD, "lua", "insert", dbName, dtName, value)
    if ok ~= 0 then
        ERROR("'%s[%s]' execute failed!!!", dbName, dtName)
    end

    return ret
end

-- 返回用户基本信息存储逻辑
return M
