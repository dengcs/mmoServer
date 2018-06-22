local social_user = require "social.social_user"
local sql_social  = require "social.sql_social"
local skynet      = require "skynet"
local queue       = require "skynet.queue"
local nickname    = require "common.nickname"

-- 快捷发送接口
local function quick_send(uid, resp, cmd, data)    
    skynet.send(GAME.SERVICE.ONLINED, "lua", "usersend", uid, "response", cmd, data)
end

local social_manager = class("SocialManager")
-- 构造管理对象（两个队列）
-- 1. uid   => user
-- 2. uname => user
function social_manager:ctor()
    self.user_list = {}
	self.name_map  = {}
	self.io_queue_lock = queue()
    self.updating_user = {} --正在更新数据的用户列表，等待推送给感兴趣的玩家
end

-- 保存数据(仅仅写入脏记录)
function social_manager:save_data()
    local list = {}
    for _, v in pairs(self.user_list) do
        if v:is_need_save() then
            -- LOG_DEBUG("uid[%s] data =   to save", v.uid)
            local data = v:serialize()
            sql_social.on_social_update(v.uid, data)
            v:clear_save()
        end
    end
end

-- 启动
function social_manager:start()
--    self:load_all_social_user()
end

-- 新用户
function social_manager:new_user(uid, data)
    assert(not self.user_list[uid], string.format("social.newuser(%s) : already exists!!!", uid))
    -- 新的用户记录
    local user = social_user.new(uid)
    if user:update_data(data) == false then
        return
    end
    self.user_list[uid] = user
    -- 问题：为什么存在没有昵称的角色
    assert(user.nickname, string.format("user(%s) not nickname!!!data(%s)", uid, table.tostring(data)))
    self.name_map[user.nickname or uid] = user
    -- 第一次保存数据
    sql_social.on_social_insert(uid, user:serialize())
end

-- 根据昵称获得uid
function social_manager:get_uid_byname(name)
    local uid = nickname.lookup(name)
    -- if not uid then
    --     LOG_INFO("%s can't found!!!", name)
    -- end
    return uid
end

-- 加载社交数据
function social_manager:load_social_data(uid)
    self.io_queue_lock(function()
        -- 先看下缓存是否有了
        if self.user_list[uid] == nil then
            local user_data = sql_social.on_load_social(uid)
            if user_data ~= nil then
                for _, v in pairs(user_data) do
                    local user = assert(social_user.new(v.uid))
                    user:un_serialize(v.data)
                    self.user_list[user.uid] = user
                    if user.nickname then
                        self.name_map [user.nickname] = user
                    end
                end
            end
        end
    end)
end

-- 根据角色id加载社交数据
function social_manager:social_user_id(uid)
    self:load_social_data(uid)

    local user = self.user_list[uid]
    if not user then
        LOG_DEBUG("social_user_id[%s] is nil", uid)
    end

    return user
end

-- 根据角色昵称加载社交数据
function social_manager:social_user_name(name)
    -- 首先昵称缓存找
    local user = self.name_map[name]
    if user then
        return user
    end

    local uid = self:get_uid_byname(name)
    if not uid then
        return
    end

    return self:social_user_id(uid)
end

-- 更新用户数据
function social_manager:update(uid,data)
    local user = self:social_user_id(uid)
    if not user then
        self:new_user(uid, data)
        return
    end

    if user:update_data(data) then
        self.updating_user[uid] = user:get_user_shared_data()
        if not self.schedule_notify then
            self.schedule_notify = this.schedule(social_manager.schedule_notify_player_shared_data, 3, SCHEDULER.NONE, self)
        end
    end
end

function social_manager:schedule_notify_player_shared_data()
    local updating_user = self.updating_user
    self.updating_user = {}
    self.schedule_notify = false
    local user_list = {}
    local function merge_user_list(list)
        for _, uid in pairs(list) do
            user_list[uid] = true
        end
    end
    --TODO:感兴趣的业务订阅此功能，并且提供接口获取感兴趣用户，然后推送给感兴趣的用户
    for uid, shared_data in pairs(updating_user) do
        user_list = {}
        local _, friend_list = skynet.call(GLOBAL.WS_NAME.FRIENDD, "lua", "get_online_friend_list", uid)
        merge_user_list(friend_list)
        local _, member_list = skynet.call(GAME.SERVICE.TONGCENTERD, "lua", "get_tong_member_uid_list", uid)
        if member_list then
            merge_user_list(member_list)
        end
        local notify = { shared_data_list = { shared_data } }
        for uid, _ in pairs(user_list) do
            quick_send(uid, "response", "notify_player_shared_data", notify)
        end
    end
end

-- 根据列表加载好友列表数据
-- 其实就是获取指定用户的指定信息（一组指定用户）
function social_manager:load_user_friend_data(list, data_list)
    for _,v in pairs(list) do
        local user = self:social_user_id(v.uid)
        if user then
			local data = user:get_user_friend_data()
			if v.time then
				data.time = v.time
			end
			if v. msg then
				data.msg = v.msg
			end
            if v.cohesion then
                data.cohesion = v.cohesion
            end
            table.insert(data_list, data)
        end
    end
end

-- 获取好友数据
-- 仍然是获取指定用户信息而已
function social_manager:get_user_friend_data(friend_list, apply_list, black_list)
    local data = {
        friend_data_list = {},
		apply_data_list  = {},
		black_data_list  = {}
    }
    self:load_user_friend_data(friend_list, data.friend_data_list)
	self:load_user_friend_data(apply_list , data.apply_data_list )
	self:load_user_friend_data(black_list , data.black_data_list )
    return data
end

-- 获取亲密好友列表数据
function social_manager:get_user_cohesion_friend_data(data_list)
    local data = {}
    for _, v in pairs(data_list) do
        local user = self:social_user_id(v.uid)
        if user then
            local user_data = user:get_user_friend_data()
            if v.cohesion then
                user_data.cohesion = v.cohesion
            end
            table.insert(data, user_data)
        end
    end
    return data
end

-- 获取好友数据
function social_manager:get_friend_data(uid)
    local user = self:social_user_id(uid)
    if user then
        return user:get_user_friend_data()
    end
    return nil
end

-- 检索数据
function social_manager:search_friend(name)
	local data =
    {
		friend_data_list = {}
	}
    local user = self:social_user_name(name)
    if user then
        local fdata = user:get_user_friend_data()
        table.insert(data.friend_data_list, fdata)
    end
    return data
end

-- 检索数据
function social_manager:search_friend_by_id(uid)
    local user = self:social_user_id(uid)
    if not user then
		LOG_DEBUG("uid[%s] social data exist",uid)
		return
	end

    return user:get_user_friend_data()
end

-- 获取推荐好友
function social_manager:get_recommend_friend_data(recommend_list)
	local data =
    {
		friend_data_list = {}
	}

	for _, v in pairs(recommend_list) do
		local user = self:social_user_id(v)
		if user then
			local fdata = user:get_user_friend_data()
			table.insert(data.friend_data_list, fdata)
		end
	end

	return data
end


-- 获取排行榜数据(排行结构 { rank = {uid, score}, ...})
function social_manager:get_rank_data(rank)
    local retval = {}
    for k, v in pairs(rank or {}) do
        local user = self:social_user_id(v.uid)
        if user then
            local data = user:get_user_rank_data()
            data.score = v.score
            data.rank_id = k
            table.insert(retval, data)
        else
            LOG_INFO("CANNOT FIND USER(%s)", v.uid)
        end
    end
    return retval
end

-- 好友排行榜数据
function social_manager:get_charts_data(uid, friend_list, charts_id)
    local data = {}
    if charts_id == "level" then
        for _,v in pairs(friend_list) do
            local user = self:social_user_id(v.uid)
            if user then
                if user.level then
                    table.insert(data, {uid = user.uid, score = user.level})
                else
                    table.insert(data, {uid = user.uid, score = 0})
                end
            end
        end
        local user = self:social_user_id(uid)
        if user then
            if user.level then
                table.insert(data, {uid = uid, score = user.level})
            else
                table.insert(data, {uid = user.uid, score = 0})
            end
        end
    else
        for _,v in pairs(friend_list) do
            local user = self:social_user_id(v.uid)
            if user then
                if user.charts_data[charts_id] then
                    table.insert(data, {uid = user.uid, score = user.charts_data[charts_id]})
                else
                    table.insert(data, {uid = user.uid, score = 0})
                end
            end
        end
        local user = self:social_user_id(uid)
        if user then
            if user.charts_data[charts_id] then
                table.insert(data, {uid = uid, score = user.charts_data[charts_id]})
            else
                table.insert(data, {uid = user.uid, score = 0})
            end
        end

    end

    return data
end

-- 清空排行数据
function social_manager:clear_charts_data(charts_id)
    for _, user in pairs(self.user_list) do
        user:clear_charts_data(charts_id)
    end
end

-- 获取指定用户数据
function social_manager:get_user_data_by_uid(uid)
    local user = self:social_user_id(uid)
    if user ~= nil then
        return user:get_user_data()
    else
        return nil
    end
end

-- 获取指定用户共享数据
function social_manager:get_user_shared_data_by_uid(uid)
    local user = self:social_user_id(uid)
    if user then
        return user:get_user_shared_data()
    end
end

--
function social_manager:get_user_shared_data_by_name(name)
    local user = self:social_user_name(name)
    if user then
        return user:get_user_shared_data()
    end
end

--
function social_manager:get_user_shared_data_list(list)
    local data_list = {}
    for _, uid in pairs(list) do
        local user = self:social_user_id(uid)
        if user then
            table.insert(data_list, user:get_user_shared_data())
        end
    end
    return data_list
end

function social_manager:search_uids_by_names(names)
    local data = {}
    for _, v in pairs(names) do
        local user = self:social_user_name(v)
        if user then
            table.insert(data,{uid = user.uid, name = v})
        end
    end
    return data
end

return social_manager
