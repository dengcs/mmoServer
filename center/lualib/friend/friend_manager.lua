local friend_user = require "friend.friend_user"
local sql_friend = require "friend.sql_friend"
local nova = require "nova"
local skynet = require "skynet"
local service = require "service"
local queue = require "skynet.queue"

-- 快捷发送接口
local function quick_send(uid, resp, cmd, data)    
    nova.send(GAME.SERVICE.ONLINED, "lua", "usersend", uid, "response", cmd, data)
end

local FriendManager = class("FriendManager")

local FRIEND_DATA_CHANGE_OPERATE = {
    OPERATE_ADD = 1, -- 添加操作
    OPERATE_DEL = 2, -- 删除操作
    OPERATE_UPDATE = 3, -- 更新操作
}

function FriendManager:ctor()
    self.user_list = {} -- 好友信息列表
    self.io_queue_lock = queue()
end

-- 获取在线好友列表
function FriendManager:get_online_friend_list(uid)
    local user = self:friend_user(uid)
    if not user then
        LOG_DEBUG("uid[%s] is nil", uid)
        return {}
    end
    local data = {}

    local _,onlines_status = skynet.call(GAME.SERVICE.ONLINED, "lua", "onlines_status")

    for _, v in pairs(user.friend_list) do
        if onlines_status[v.uid] then
            table.insert(data, v.uid)
        end
    end
    return data
end

-- 好友系统好友类型数据变动通知
-- @param uid 需通知uid
-- @param changed_uid 变化的uid
function FriendManager:friend_data_changed_in_friend_notify(uid, changed_uid)
    local user = self:friend_user(uid)
    if user then
        local f_data = user.friend_list[changed_uid]
        if f_data then
            quick_send(uid, "response", "friend_data_changed_notify",{
                operate = FRIEND_DATA_CHANGE_OPERATE.OPERATE_UPDATE,
                changed_uid = changed_uid,
                simple_friend_data = {
                    uid = f_data.uid,
                    cohesion = f_data.cohesion
                }
            })
        end
    end
end

-- 加载所有数据
--function FriendManager:load_all_friend_user()
--    LOG_DEBUG("load_all_friend_user          ...")
--    local  user_data_list = sql_friend.on_load_all_friend()
--    if user_data_list ~= nil then
--        for _, v in pairs(user_data_list) do
--            local user = friend_user.new(v.uid)
--            user:un_serialize(v.data)
--            self.user_list[v.uid] = user
--        end
--    end
--
--end

-- 保存数据
function FriendManager:save_data()

    local list = {}
    for _, v in pairs(self.user_list) do
        if v:is_need_save() then
            --LOG_DEBUG("uid[%s] data = %s  to save", v.uid, table.tostring(v:get_user_data()))
            local data = v:serialize()
            sql_friend.on_friend_update(v.uid, data)
            v:clear_save()
        end
    end
end

function FriendManager:start()
    -- self:load_all_friend_user()
end

-- 新用户
function FriendManager:new_user(uid)
	if self.user_list[uid] then
		LOG_ERROR("uid[%s] friend data exist.", uid)
		return
	end
    local user = friend_user.new(uid)
    self.user_list[user.uid] = user

    -- 第一次保存数据
    sql_friend.on_friend_insert(user.uid, user:serialize())
end

-- 加载好友数据
function FriendManager:load_friend_data(uid)
    self.io_queue_lock(function()
        -- 没有数据则数据库加载
        if self.user_list[uid] == nil then
            local  user_data = sql_friend.on_load_friend(uid)
            if user_data ~= nil then
                for _, v in pairs(user_data) do
                    local user = friend_user.new(v.uid)
                    user:un_serialize(v.data)
                    self.user_list[v.uid] = user
                end
            end
        end
    end)
end

-- 获得好友对象
function FriendManager:friend_user(uid)
    self:load_friend_data(uid)
    local user = self.user_list[uid]

    if not user then
        LOG_DEBUG("friend_user[%s] is nil", uid)
    end

    return user
end

-- 添加好友
-- TODO: 优化满了以后不在循环
function FriendManager:add_friend(uid, proto)
    local user = self:friend_user(uid)
    if not user then
        LOG_DEBUG("uid[%s] is nil", uid)
        -- TODO: 是否返回用户不存在
        return
    end

    local ret = self:add_user_to_apply(proto, user)
    if ret ~= 0 then
		LOG_ERROR(uid .. 'add ' .. proto.uid ..' ret=' .. ret)
    end
end

-- 添加好友到申请列表
function FriendManager:add_user_to_apply(proto, user)
	local uid = proto.uid
    local friend = self:friend_user(uid)

    if not friend then
        return ERRCODE.FRIEND_NOT_EXIST
    end

    local ret = 0
    ret = user:add_applied_check(uid)
    if ret ~= 0 then
        return ret
    end
    ret = friend:add_apply_check(user.uid)
    if ret ~= 0 then
        return ret
    else
        user:add_applied(uid)
        friend:add_apply(user.uid, proto.msg)
        -- 发送通知
        quick_send(friend.uid, "response","friend_apply_tip_notify", friend:get_friend_tip())
    end

    return ret
end

-- 删除好友
function FriendManager:del_friend(uid, uids)
    local user = self:friend_user(uid)
    if not user then
        LOG_DEBUG("uid[%s] is nil", uid)
        return
    end

    for _, fuid in pairs(uids) do
        if user:is_in_friend(fuid) then
            local friend = self:friend_user(fuid)
            if friend then
                friend:del_friend(uid)
                user:del_friend(fuid)

                -- tip: 通知双方好友删除事件
                quick_send(uid, "response", "friend_data_changed_notify",{
                    operate = FRIEND_DATA_CHANGE_OPERATE.OPERATE_DEL,
                    changed_uid = fuid
                })

                quick_send(fuid, "response", "friend_data_changed_notify",{
                    operate = FRIEND_DATA_CHANGE_OPERATE.OPERATE_DEL,
                    changed_uid = uid
                })
                LOG_DEBUG("send uid[%s]  op.del %s",fuid, uid)
            end
        end
    end
end

-- 同意申请
function FriendManager:agree_friend(uid, uids)
    local user = self:friend_user(uid)
    if not user then
        LOG_DEBUG("uid[%s] is nil", uid)
        -- TODO: 是否返回用户不存在
        return
    end
    local notify_data = {}
    local new_friend_list = {}
    for _, fuid in pairs(uids) do
        local friend = self:friend_user(fuid)
        local ret = 0
        if friend then
            ret = user:agree_check(fuid)
            if ret == 0 then
                ret = friend:agreed_check(uid)
            end
            if ret == 0 then
                user:agree_apply(fuid)
                friend:agree_applied(uid)

                if not notify_data[uid] then
                    notify_data[uid] = user:get_friend_tip()
                end

                if not notify_data[fuid] then
                    notify_data[fuid] = friend:get_friend_tip()
                end

                -- tip: 新添加好友
                if not new_friend_list[uid] then
                    new_friend_list[uid] = {}
                end

                table.insert(new_friend_list[uid], fuid)

                if not new_friend_list[friend.uid] then
                    new_friend_list[friend.uid] = {}
                end
                table.insert(new_friend_list[fuid], uid)

            end

            if ret ~= 0 then
                LOG_DEBUG("%s agree %s ret= %d", uid, fuid, ret)
            end
        end
    end

    -- 发送通知
    for k, v in pairs(notify_data) do
        quick_send(k, "response","friend_apply_tip_notify", v)
    end

    -- 发送添加好友数据
    local _,onlines_status = skynet.call(GAME.SERVICE.ONLINED, "lua", "onlines_status")
    for k, v in pairs(new_friend_list) do
        if onlines_status[k] then
            local t_user = self:friend_user(k)
            if t_user then
                for _, v1 in pairs(v) do
                    local fdata = t_user:get_single_friend_data(v1)
                    if fdata then
                        quick_send(k, "response","friend_data_changed_notify", {
                            operate = FRIEND_DATA_CHANGE_OPERATE.OPERATE_ADD,
                            changed_uid = v1,
                            friend_data = fdata
                        })
                    end
                end
            end
        end
    end
end

function FriendManager:refuse_friend(uid, uids)
    local user = self:friend_user(uid)
    if not user then
        LOG_DEBUG("uid[%s] is nil", uid)
        -- TODO: 是否返回用户不存在
        return
    end

    for _, fuid in pairs(uids) do
        local friend = self:friend_user(fuid)
        local ret = 0
        if friend then
            ret = user:refuse_check(fuid)
            if ret == 0 then
                ret = friend:agreed_check(uid)
            end
            if ret == 0 then
                user:refuse(fuid)
                friend:refused(uid)
            end

            if ret ~= 0 then
                LOG_DEBUG("%s refuse %s ret= %d", uid, fuid, ret)
            end
        end
    end
end

function FriendManager:add_blacklist(uid, uids)
    local user = self:friend_user(uid)
    if not user then
        LOG_DEBUG("uid[%s] is nil", uid)
        -- TODO: 是否返回用户不存在
        return
    end

    for _, fuid in pairs(uids) do
        local friend = self:friend_user(fuid)
        local ret = 0
        if friend then
            ret = user:add_black_check(fuid)
            if ret == 0 then
                user:add_black(fuid)
            end
            if ret ~= 0 then
                LOG_DEBUG("%s add_black %s ret= %d", uid, fuid, ret)
            end
        end
    end
end

function FriendManager:del_blacklist(uid, uids)
    local user = self:friend_user(uid)
    if not user then
        LOG_DEBUG("uid[%s] is nil", uid)
        -- TODO: 是否返回用户不存在
        return
    end

    for _, fuid in pairs(uids) do
        user:del_black(fuid)
    end
end

-- 获取好友数据
function FriendManager:get_friend_data(uid)
    local user = self:friend_user(uid)
    if not user then
        LOG_DEBUG("uid[%s] is nil", uid)
        -- TODO: 是否返回用户不存在
        return
    end
    local data = user:get_friend_data()
    return data
end

-- 获取亲密的好友列表数据
function FriendManager:get_cohesion_friend_data(uid)
    local user = self:friend_user(uid)
    if not user then
        LOG_DEBUG("uid[%s] is nil", uid)
        -- TODO: 是否返回用户不存在
        return
    end
    local data = user:get_cohesion_friend_data()
    return data
end

-- 获取超过特定亲密值的好友列表数据 包含 cohesion值的
function FriendManager:get_friend_data_over_cohesion(uid, cohesion)
    local user = self:friend_user(uid)
    if not user then
        LOG_DEBUG("uid[%s] is nil", uid)
        -- TODO: 是否返回用户不存在
        return
    end
    local data = user:get_friend_data_over_cohesion(cohesion)
    return data
end

--获取关联关系数据
function FriendManager:get_relation_data(uid)
    local user = self:friend_user(uid)
    if not user then
        LOG_DEBUG("uid[%s] is nil", uid)
        -- TODO: 是否返回用户不存在
        return
    end
    local data = user:get_relation_data()
    return data
end

-- 获取提示信息
function FriendManager:get_friend_tip(uid)
    local user = self:friend_user(uid)
    if not user then
        LOG_DEBUG("uid[%s] is nil", uid)
        -- TODO: 是否返回用户不存在
        return
    end
    local data = user:get_friend_tip()
    return data
end

-- 更新tip
function FriendManager:update_friend_tip(uid, tip_data)
    local user = self:friend_user(uid)
    if not user then
        LOG_DEBUG("uid[%s] is nil", uid)
        -- TODO: 是否返回用户不存在
        return
    end
    user:update_friend_tip(tip_data)
end

-- 添加好感
function FriendManager:add_cohesion(uids)
    local ret = 0
    local len = #uids
    for m=1,len - 1 do
        for n = m + 1, len do
            local uid = uids[m]
            local fuid = uids[n]
            local user = self:friend_user(uid)
            local fuser = self:friend_user(fuid)
            if user and fuser then
                ret = user:add_cohesion_check(fuid)
                if ret == 0 then
                    user:add_cohesion(fuid)
                    fuser:add_cohesion(uid)
                    -- tip: 通知好友列表更新
                    self:friend_data_changed_in_friend_notify(uid,fuid)
                    self:friend_data_changed_in_friend_notify(fuid,uid)
                end
            end
        end
    end
end

-- 获取亲密关系
function FriendManager:get_cohesion_relation(uids)
    local data = {}
    local len = #uids
    for m = 1, len - 1 do
        for n = m + 1, len do
            local uid = uids[m]
            local fuid = uids[n]
            local user = self:friend_user(uid)
            if user then
                if user:is_in_cohesion(fuid) then
                    table.insert(data,{uid,fuid})
                end
            end
        end
    end
    return data
end

-- 获取好友关系
function FriendManager:get_friend_relation(uids)
    local data = {}
    local len = #uids
    for m = 1, len - 1 do
        for n = m + 1, len do
            local uid = uids[m]
            local fuid = uids[n]
            local user = self:friend_user(uid)
            if user then
                if user:is_in_friend(fuid) then
                    table.insert(data,{uid,fuid, user.friend_list[fuid].cohesion})
                end
            end
        end
    end
    return data
end

-- 是否屏蔽
function FriendManager:is_shielded(uid, ch_uid, need_friend)
    local user = self:friend_user(uid)
    if not user then
        LOG_DEBUG("uid[%s] is nil", uid)
        return true
    end

    local shielded = false
    if user:is_in_black(ch_uid) then
        shielded = true
    end

    if not shielded and need_friend then
        if not user:is_in_friend(ch_uid) then
            shielded = true
        end
    end

    return shielded
end

-- 好友排行
function FriendManager:get_charts_data(uid, charts_id)
    local user = self:friend_user(uid)
    if not user then
        LOG_DEBUG("uid[%s] is nil", uid)
        return nil
    end
    return user:get_charts_data(charts_id)
end

-- 判断两个角色是否好友关系
function FriendManager:is_friend(u1, u2)
    local user = self:friend_user(u1)
    if user ~= nil then
        return user:is_in_friend(u2)
    end
    return false
end

return FriendManager
