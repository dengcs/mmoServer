local skynet =require "skynet"
local service = require "service"
local social_manager = require "social.social_manager"

local CMD = {}

local social_save_interval = skynet.getenv("social_save_interval") or 60
-- 管理器
local social_mgr = nil
-- 定时任务id
local time_id

-- 社交保存数据操作
local function save_data()
    --LOG_DEBUG("sociald save data ......")
    social_mgr:save_data()
end

-- 启动
local function init_handler()
    social_mgr =social_manager.new()
    social_mgr:start()
    time_id = this.schedule(save_data, social_save_interval , SCHEDULER.REPEAT_FOREVER)
end

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

-- 获取好友列表数据
function CMD.get_user_friend_data(friend_list, apply_list, black_list)
    --LOG_DEBUG("sociald.get_user_friend_data .............")
    return social_mgr:get_user_friend_data(friend_list, apply_list, black_list)
end

-- 获取亲密好友列表数据
function CMD.get_user_cohesion_friend_data(data_list)
    return social_mgr:get_user_cohesion_friend_data(data_list)
end

-- 搜索玩家
function CMD.search_friend(name)
	return social_mgr:search_friend(name)
end

-- 获取推荐好友数据列表
function CMD.get_recommend_friend_data(recommend_list)
	--LOG_DEBUG("sociald.get_recommend_friend_data .............")
	return social_mgr:get_recommend_friend_data(recommend_list)
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

-- 获取好友排行数据
function CMD.get_charts_data(uid, friend_list, charts_id)
    return social_mgr:get_charts_data(uid, friend_list, charts_id)
end

-- 获取用户共享数据
function CMD.get_user_shared_data_by_uid(uid)
    return social_mgr:get_user_shared_data_by_uid(uid)
end

--
function CMD.get_user_shared_data_list(list)
    return social_mgr:get_user_shared_data_list(list)
end

-- 清空排行数据
function CMD.clear_charts_data(charts_id)
    return social_mgr:clear_charts_data(charts_id)
end

function CMD.search_uids_by_names(names)
    return social_mgr:search_uids_by_names(names)
end

-- 退出处理
local function exit_handler()
    this.unschedule_all()

    save_data()
end

-- 服务注册
local handler = {}

-- 消息分发逻辑
-- 1. 消息来源
-- 2. 消息类型
-- 3. 消息内容
function handler.command_handler(source, cmd, ...)
	local fn = CMD[cmd]
	if fn then
		return fn(...)
	else
		ERROR("svcmanager : command[%s] can't find!!!", cmd)
	end
end

handler.init_handler = init_handler
handler.exit_handler = exit_handler

service.start(handler)