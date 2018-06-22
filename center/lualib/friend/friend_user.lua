local skynet = require "skynet"
local nova = require "nova"
local FriendUser = class("FriendUser")

-- 最大亲密度
local MAX_COHESION_VALUE = 1
-- 最大好友数
local MAX_FRIEND_VALUE = 1000
-- 最大申请列表数
local MAX_APPLY_VALUE = 1000
-- 最大被申请列表数
local MAX_APPLIED_VALUE = 1000
-- 最大黑名单数
local MAX_BLACK_VALUE = 1000

-- 角色好友记录
function FriendUser:ctor(uid)
    self.uid             = uid
    self.friend_num      = 0      -- 好友人数
    self.friend_list     = {}     -- 好友表
    self.apply_num       = 0      -- 申请列表数
    self.apply_list      = {}     -- 自己申请表
    self.applied_num     = 0      -- 被申请列表数
    self.applied_list    = {}     -- 自己被申请列表
    self.black_num       = 0      -- 黑名单数
    self.black_list      = {}     -- 黑名单
    self.cohesion_list   = {}     -- 亲密列表
    self.friend_tip_flag = 0      -- 好友申请提示标志
    self.apply_tip_flag  = 0      -- 好友列表提示标志
    self.need_save_flag  = false
end

function FriendUser:set_need_save()
    self.need_save_flag = true
end

function FriendUser:clear_save()
    self.need_save_flag = false
end

function FriendUser:is_need_save()
    return self.need_save_flag
end

-- 反序列化
function FriendUser:un_serialize(data)
    local friend_data = skynet.unpack(data)
    if friend_data.friend_list then
        for _, v in pairs(friend_data.friend_list) do
            self.friend_list[v.uid] = v
        end
        self.friend_num = #friend_data.friend_list
    end

    if friend_data.apply_list then
        for _, v in pairs(friend_data.apply_list) do
            self.apply_list[v.uid] = v
        end
        self.apply_num = #friend_data.apply_list
    end

    if friend_data.applied_list then
        for _, v in pairs(friend_data.applied_list) do
            self.applied_list[v.uid] = v
        end
        self.applied_num = #friend_data.applied_list
    end

    if friend_data.black_list then
        for _, v in pairs(friend_data.black_list) do
            self.black_list[v.uid] = v
        end
        self.black_num = #friend_data.black_list
    end

    if friend_data.cohesion_list then
        for _, v in pairs(friend_data.cohesion_list) do
            self.cohesion_list[v.uid] = v
        end
    end

    self.friend_tip_flag = friend_data.friend_tip_flag
    self.apply_tip_flag  = friend_data.apply_tip_flag

end

-- 获取用户数据
function FriendUser:get_user_data()
    local data = {
        uid = self.uid,
        apply_tip_flag = self.apply_tip_flag,
        friend_tip_flag = self.friend_tip_flag,
        friend_list = {},
        apply_list = {},
        applied_list = {},
        black_list = {},
        cohesion_list = {},
    }

    for _,v in pairs(self.friend_list) do
        table.insert(data.friend_list, v)
    end

    for _,v in pairs(self.apply_list) do
        table.insert(data.apply_list, v)
    end

    for _,v in pairs(self.applied_list) do
        table.insert(data.applied_list, v)
    end

    for _,v in pairs(self.black_list) do
        table.insert(data.black_list, v)
    end

    for _,v in pairs(self.cohesion_list) do
        table.insert(data.cohesion_list, v)
    end
    return data
end

-- 获取关联关系数据（好友，申请者，黑名单都一起出来？？）
function FriendUser:get_relation_data()
	local relation_uids = {}
	relation_uids[self.uid] = self.uid

    for k,_ in pairs(self.friend_list) do
        relation_uids[k] = k
    end

    for k,_ in pairs(self.apply_list) do
        relation_uids[k] = k
    end

    for k,_ in pairs(self.applied_list) do
        relation_uids[k] = k
    end

    for k,_ in pairs(self.black_list) do
        relation_uids[k] = k
    end
	return relation_uids
end

-- 序列化
function FriendUser:serialize()
    local data = self:get_user_data()
    local res = skynet.packstring(data)
    return res
end

-- 是否是好友
function FriendUser:is_in_friend(uid)
    if self.friend_list[uid] then
        return true
    end

    return false
end

-- 是否在申请列表
function FriendUser:is_in_apply(uid)
    if self.apply_list[uid] then
        return true
    end
    return false
end

-- 是否在发起申请列表
function FriendUser:is_in_applied(uid)
    if self.applied_list[uid] then
        return true
    end
    return false
end

-- 是否在黑名单列表
function FriendUser:is_in_black(uid)
    if self.black_list[uid] then
        return true
    end
    return false
end

-- 是否在亲密列表
function FriendUser:is_in_cohesion(uid)
    if self.cohesion_list[uid] then
        return true
    end
    return false
end

-- 是否满
function FriendUser:is_friend_full()
    if self.friend_num > MAX_FRIEND_VALUE then
        return true
    end
    return false
end

-- 是否申请列表已满
function FriendUser:is_apply_full()
    if self.apply_num > MAX_APPLY_VALUE then
        return true
    end
    return false
end

-- 是否发起申请列表已满
function FriendUser:is_applied_full()
    if self.applied_num > MAX_APPLIED_VALUE then
        return true
    end
    return false
end

-- 是否黑名单列表已满
function FriendUser:is_black_full()
    if self.black_num > MAX_BLACK_VALUE then
        return true
    end
    return false
end

-- 添加到好友列表检查
-- 检查
-- 不修改数据
function FriendUser:add_friend_check(uid)
    if self.friend_list[uid] then
        LOG_DEBUG("%s and %s is friend", uid, self.uid)
        return ERRCODE.FRIEND_ALREADY_FRIEND
    end

    if self:is_friend_full() then
        LOG_DEBUG("%s friend_list is full", self.uid)
        return ERRCODE.FRIEND_FRIEND_FULL
    end
    return 0
end

-- 同意检查
function FriendUser:agree_check(uid)
    if self:is_friend_full() then
        LOG_DEBUG("%s friend_list is full", self.uid)
        return ERRCODE.FRIEND_FRIEND_FULL
    end

    if not self.apply_list[uid] then
        LOG_DEBUG("%s not in %s apply_list", uid, self.uid)
        return FRIEND_NOT_APPLY
    end

    return 0
end

-- 被同意检查
function FriendUser:agreed_check(uid)
    if self:is_friend_full() then
        LOG_DEBUG("%s friend_list is full", self.uid)
        return ERRCODE.FRIEND_FRIEND_FULL
    end

    if not self.applied_list[uid] then
        LOG_DEBUG("%s not in %s applied_list", uid, self.uid)
        return FRIEND_NOT_APPLIED
    end

    return 0
end

-- 拒绝检查
function FriendUser:refuse_check(uid)
    if not self.apply_list[uid] then
        LOG_DEBUG("%s not in %s apply_list", uid, self.uid)
        return FRIEND_NOT_APPLY
    end
    return 0
end

--被拒绝检查
function FriendUser:refused_check(uid)
    if not self.applied_list[uid] then
        LOG_DEBUG("%s not in %s apply_list", uid, self.uid)
        return FRIEND_NOT_APPLIED
    end
    return 0
end

-- 添加到发起申请列表
-- 检查
-- 不修改数据
function FriendUser:add_applied_check(uid)
    if self.applied_list[uid] then
        LOG_DEBUG("%s in %s applied_list", uid, self.uid)
        return ERRCODE.FRIEND_ALREADY_APPLIED
    end

    if self.friend_list[uid] then
        LOG_DEBUG("%s and %s is friend", uid, self.uid)
        return ERRCODE.FRIEND_ALREADY_FRIEND
    end

    if self:is_friend_full() then
        LOG_DEBUG("%s friend_list is full", self.uid)
        return ERRCODE.FRIEND_FRIEND_FULL
    end

    if self:is_applied_full() then
        local temp = self.applied_list[uid]
        if temp then
            LOG_ERROR("%s is in %s applied_list", uid, self.uid)
            return ERRCODE.FRIEND_ALREADY_APPLIED
        end
        return ERRCODE.FRIEND_APPLIED_FULL
    end
    return 0
end

-- 添加到申请列表
-- 检查
-- 不修改数据
function FriendUser:add_apply_check(uid)
    if self.apply_list[uid] then
        LOG_DEBUG("%s in %s apply_list", uid, self.uid)
        return ERRCODE.FRIEND_ALREADY_APPLY
    end

    if self.friend_list[uid] then
        LOG_DEBUG("%s and %s is friend", uid, self.uid)
        return ERRCODE.FRIEND_ALREADY_FRIEND
    end

    if self:is_friend_full() then
        LOG_DEBUG("%s friend_list is full", self.uid)
        return ERRCODE.FRIEND_FRIEND_FULL
    end

    if self:is_apply_full() then
        local old_apply = self.apply_list[uid]
        if old_apply then
            LOG_ERROR("%s is in %s apply_list", uid, self.uid)
            return ERRCODE.FRIEND_ALREADY_APPLY
        end
        return ERRCODE.FRIEND_APPLY_FULL
    end

    return 0
end

-- 添加到黑名单列表
-- 检查
-- 不修改数据
function FriendUser:add_black_check(uid)
    if self:is_black_full() then
        local old_apply = self.black_list[uid]
        if old_apply then
            LOG_ERROR("%s is in %s black_list", uid, self.uid)
            return ERRCODE.FRIEND_ALREADY_BLACK
        end
    end

    return 0
end

-- 添加好感检查
function FriendUser:add_cohesion_check(uid)
    local friend  = self.friend_list[uid]
    if not friend then
        return ERRCODE.FRIEND_NOT_FRIEND
    end


    return 0
end

-- 不检查
function FriendUser:add_cohesion(uid)
    local friend = self.friend_list[uid]
    friend.cohesion = friend.cohesion + 1
    if friend.cohesion >= MAX_COHESION_VALUE and self.cohesion_list[uid] == nil then
        self.cohesion_list[uid] = {uid = uid,time = math.floor(skynet.time())}
    end

    self:set_need_save()
end

-- 添加到发起申请列表
-- 不检查
function FriendUser:add_applied(uid)
    self.applied_list[uid] = {
        uid = uid,
        time = math.floor(skynet.time())
    }
    self.applied_num = self.applied_num + 1

    self:set_need_save()
end

-- 删除applied
function FriendUser:del_applied(uid)
    if self.applied_list[uid] then
        self.applied_list[uid] = nil
        self.applied_num = self.applied_num - 1
        self:set_need_save()
    end
end

-- 添加到申请列表
function FriendUser:add_apply(uid, msg)
    local apply_user = {
        uid = uid,
        time = math.floor(skynet.time()),
		msg = msg
    }

    self.apply_tip_flag = 1

    self.apply_list[uid] = apply_user
    self.apply_num = self.apply_num + 1

    self:set_need_save()
end

-- 删除apply
function FriendUser:del_apply(uid)
    if self.apply_list[uid] then
        self.apply_list[uid] = nil
        self.apply_num = self.apply_num - 1
        self:set_need_save()
    end
end

-- 添加好友
-- 不做任何检查
function FriendUser:add_friend(uid)
    self.friend_list[uid] = {uid = uid, cohesion = 0, time = math.floor(skynet.time())}
    self.friend_num = self.friend_num + 1
    self.friend_tip_flag = 1
    self:set_need_save()
end

-- 删除好友
function FriendUser:del_friend(uid)
    if self.cohesion_list[uid] then
        self.cohesion_list[uid] = nil
    end
    if self.friend_list[uid] then
        self.friend_list[uid] = nil
        self.friend_num = self.friend_num - 1
        self:set_need_save()
    end
end

-- 添加好友
-- 不做任何检查
function FriendUser:add_black(uid)
    self.black_list[uid] = {uid = uid, time = math.floor(skynet.time())}
    self.black_num = self.black_num + 1
    self:set_need_save()
end

-- 删除黑名单
function FriendUser:del_black(uid)
    if self.black_list[uid] then
        self.black_list[uid] = nil
        self.black_num = self.black_num - 1
        self:set_need_save()
    end
end

-- 同意申请
-- 不检测
function FriendUser:agree_apply(uid)

    self.apply_list[uid] = nil
    self.apply_num = self.apply_num - 1
    self:add_friend(uid)
    self:set_need_save()
end

-- 被同意申请
function FriendUser:agree_applied(uid)
    self.applied_list[uid] = nil
    self.applied_num = self.applied_num - 1
    self:add_friend(uid)
    self:set_need_save()
end

function FriendUser:refuse(uid)
    self.apply_list[uid] = nil
    self.apply_num = self.apply_num - 1
    self:set_need_save()
end

function FriendUser:refused(uid)
    self.applied_list[uid] = nil
    self.applied_num = self.applied_num - 1
    self:set_need_save()
end

-- 获取好友列表
function FriendUser:get_friend_data()
    local _,data = nova.call(GLOBAL.WS_NAME.SOCIALD, "lua", "get_user_friend_data", self.friend_list, self.apply_list, self.black_list)
    return data
end

-- 获取好友列表
function FriendUser:get_cohesion_friend_data()
    local cohesion_list = {}
    for uid, _ in pairs(self.cohesion_list) do
        table.insert(cohesion_list, self.friend_list[uid])
    end
    local _,data = nova.call(GLOBAL.WS_NAME.SOCIALD, "lua", "get_user_cohesion_friend_data", cohesion_list)
    return data
end

-- 获取超过特定亲密值的好友列表数据 包含 cohesion值的
function FriendUser:get_friend_data_over_cohesion(cohesion)
    local cohesion_list = {}
    for _, friend in pairs(self.friend_list) do
        if friend.cohesion >= cohesion then
            table.insert(cohesion_list, friend)
        end
    end
    local _,data = nova.call(GLOBAL.WS_NAME.SOCIALD, "lua", "get_user_cohesion_friend_data", cohesion_list)
    return data
end

-- 获取一个好友数据
function FriendUser:get_single_friend_data(uid)
    local code, data = nova.call(GLOBAL.WS_NAME.SOCIALD, "lua", "get_friend_data",uid)
    if code > 0 then
        return nil
    end
    if data then
        local friend = self.friend_list[uid]
        if friend then
            data.time = friend.time
            data.cohesion = friend.cohesion
        end
    end
    return data
end

-- 获取提示信息
function FriendUser:get_friend_tip()
    local data = {
        apply_tip_flag = self.apply_tip_flag,
        friend_tip_flag = self.friend_tip_flag
    }
    return data
end

-- 更新tip
function FriendUser:update_friend_tip(tip_data)
    self.apply_tip_flag = tip_data.apply_tip_flag or self.apply_tip_flag
    self.friend_tip_flag = tip_data.friend_tip_flag or self.friend_tip_flag
    self:set_need_save()
end

-- 获取好友排行数据
function FriendUser:get_charts_data(charts_id)
    local _, data = nova.call(GLOBAL.WS_NAME.SOCIALD, "lua", "get_charts_data", self.uid, self.friend_list,charts_id)
    return data
end


return FriendUser
