local skynet    =   require "skynet"
local service   =   require "factory.service"

local CMD = {}

-- 管理器
local social_mgr = nil

-- 新用户
function CMD.new_user(uid, data)
    --LOG_DEBUG("sociald.new_user .............")
    social_mgr:new_user(uid, data)
end

-- 同步数据
function CMD.update_user(uid, data)
    --LOG_DEBUG("sociald.update_user .............")
    social_mgr:update(uid, data)
end

-- 搜索玩家
function CMD.search_friend(name)
	return social_mgr:search_friend(name)
end

-- 获取uid包装成好友型的数据
function CMD.get_friend_data(uid)
    return social_mgr:get_friend_data(uid)
end

function CMD.search_friend_by_id(uid)
    return social_mgr:search_friend_by_id(uid)
end

-- 获取排行数据
function CMD.get_rank_data(rank)
    return social_mgr:get_rank_data(rank)
end

-- 获取指定用户数据
function CMD.get_user_data_by_uid(uid)
    return social_mgr:get_user_data_by_uid(uid)
end

function CMD.search_uids_by_names(names)
    return social_mgr:search_uids_by_names(names)
end

-- 服务注册
local server = {}

-- 消息分发逻辑
-- 1. 消息来源
-- 2. 消息类型
-- 3. 消息内容
function server.command_handler(source, cmd, ...)
	local fn = CMD[cmd]
	if fn then
		return fn(...)
	else
		ERROR("svcmanager : command[%s] can't find!!!", cmd)
	end
end

service.start(server)