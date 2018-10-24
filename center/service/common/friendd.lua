local skynet =require "skynet"
local friend_manager = require "friend.friend_manager"

local service = require "service"

local CMD = {}

local friend_save_interval = skynet.getenv("friend_save_interval") or 60

-- 管理器
local friend_mgr
-- 定时任务id
local time_id

-- 社交保存数据操作
local function save_data()
    --LOG_DEBUG("friendd save data ......")
    friend_mgr:save_data()
end

-- 启动
local function init_handler()
    friend_mgr =friend_manager.new()
    friend_mgr:start()
    time_id = this.schedule(save_data, friend_save_interval , SCHEDULER.REPEAT_FOREVER)
end

function CMD.join_handler(uid)
    friend_mgr:load_friend_data(uid)
end

-- 新用户
function CMD.new_user(uid)
    --LOG_DEBUG("friendd.new_user .............")
    friend_mgr:new_user(uid)
end

-- 添加好友
function CMD.add_friend(uid, uids)
    --LOG_DEBUG("friendd.add_friend .............")
    friend_mgr:add_friend(uid, uids)
end

-- 删除好友
function CMD.del_friend(uid, uids)
    --LOG_DEBUG("friendd.del_friend .............")
    friend_mgr:del_friend(uid, uids)
end

-- 同意好友
function CMD.agree_friend(uid, uids)
    --LOG_DEBUG("friendd.agree_friend .............")
    friend_mgr:agree_friend(uid, uids)
end

-- 拒绝好友
function CMD.refuse_friend(uid, uids)
    --LOG_DEBUG("friendd.refuse_friend .............")
    friend_mgr:refuse_friend(uid, uids)
end

-- 添加黑名单
function CMD.add_blacklist(uid, uids)
    --LOG_DEBUG("friendd.add_blacklist .............")
    friend_mgr:add_blacklist(uid, uids)
end

-- 删除黑名单
function CMD.del_blacklist(uid, uids)
    --LOG_DEBUG("friendd.del_blacklist .............")
    friend_mgr:del_blacklist(uid, uids)
end

-- 获取好友列表数据
function CMD.get_friend_data(uid)
    --LOG_DEBUG("friendd.get_friend_data .............")
    return friend_mgr:get_friend_data(uid)
end

-- 获取亲密的好友列表数据
function CMD.get_cohesion_friend_data(uid)
    return friend_mgr:get_cohesion_friend_data(uid)
end

-- 获取超过特定亲密值的好友列表数据 包含 cohesion值的
function CMD.get_friend_data_over_cohesion(uid, cohesion)
    return friend_mgr:get_friend_data_over_cohesion(uid, cohesion)
end

--获取关联关系数据
function CMD.get_relation_data(uid)
    return friend_mgr:get_relation_data(uid)
end

-- 获取提示信息
function CMD.get_friend_tip(uid)
    --LOG_DEBUG("friendd.get_friend_tip ......." .. uid)
    return friend_mgr:get_friend_tip(uid)
end

-- 更新tip
function CMD.update_friend_tip(uid,tip_data)
    friend_mgr:update_friend_tip(uid, tip_data)
end

-- 添加亲密度
function CMD.add_cohesion(uids)
    friend_mgr:add_cohesion(uids)
end

-- 从uid列表中获取配对亲密关系
function CMD.get_cohesion_relation(uids)
    return friend_mgr:get_cohesion_relation(uids)
end

-- 从uid列表中获取配对好友关系
function CMD.get_friend_relation(uids)
    return friend_mgr:get_friend_relation(uids)
end

function CMD.get_online_friend_list(uid)
    return friend_mgr:get_online_friend_list(uid)
end

-- 校验是否被屏蔽
-- @uid uid
-- @ch_uid 校验id
-- @need_friend 是否需要是好友
function CMD.is_shielded(uid, ch_uid, need_friend)
    friend_mgr:is_shielded(uid, ch_uid, need_friend)
end

-- 获取好友排行数据
function CMD.get_charts_data(uid, charts_id)
    return friend_mgr:get_charts_data(uid, charts_id)
end

-- 判断角色是否好友关系
function CMD.is_friend(u1, u2)
    return friend_mgr:is_friend(u1, u2)
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