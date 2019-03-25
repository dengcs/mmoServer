---------------------------------------------------------------------
--- 社交服务
---------------------------------------------------------------------
local service   = require "factory.service"
local skynet    = require "skynet"
local database  = require "common.database"

local tinsert = table.insert

-----------------------------------------------------------
--- 常量表
-----------------------------------------------------------

-- 最大申请数量
local MAX_APPLICANTS_VALUE = 100

-- 最大好友数量
local MAX_FRIENDS_VALUE    = 100

-- 最大敌人数量
local MAX_ENEMIES_VALUE    = 100

-----------------------------------------------------------
--- 内部变量/内部逻辑
-----------------------------------------------------------

-----------------------------------------------------------
--- 内部類
-----------------------------------------------------------

-- 社交数据模型
local udata = class("udata")

-- 构建模型实例
-- 1. 角色编号
function udata:ctor(pid)
    self.dirty              = false                         -- 数据脏标记
    self.pid                = pid                           -- 角色编号
    self.friend             = { len = 0, list = {} }        -- 好友信息
    self.enemy              = { len = 0, list = {} }        -- 敌人信息
    self.applicant          = { len = 0, list = {} }        -- 申请信息（申请成为目标好友）
    self.authorize          = { len = 0, list = {} }        -- 申请信息（目标申请等待批准）
    self.friendly_send      = { len = 0, list = {} }        -- 友情贈送
    self.friendly_recive    = { len = 0, list = {} }        -- 友情接收
    self.group              = { len = 0, list = {} }        -- 群信息
    self.subscribe          = { len = 0, list = {} }        -- 订阅通知
end

-- 序列化
function udata:serialize()
    return skynet.packstring(
            {
                friend          = self.friend,
                enemy           = self.enemy,
                applicant       = self.applicant,
                authorize       = self.authorize,
                friendly_send   = self.friendly_send,
                friendly_recive = self.friendly_recive,
                group           = self.group,
                subscribe       = self.subscribe,
            })
end

-- 反序列化
function udata:unserialize(v)
    if v then
        local vdata = skynet.unpack(v)
        self.friend             = vdata.friend
        self.enemy              = vdata.enemy
        self.applicant          = vdata.applicant
        self.authorize          = vdata.authorize
        self.friendly_send      = vdata.friendly_send
        self.friendly_recive    = vdata.friendly_recive
        self.group              = vdata.group
    end
end

-- 检查脏标记
function udata:check_dirty()
    if self.dirty then
        return true
    else
        return false
    end
end

-- 设置脏标记
function udata:set_dirty()
    self.dirty = true
end

-- 清理脏标记
function udata:clear_dirty()
    self.dirty = false
end

-- 好友判断
function udata:is_friend(pid)
    if self.friend.list[pid] then
        return true
    else
        return false
    end
end

-- 增加好友
function udata:add_friend(pid)
    if (self.friend.list[pid] == nil) then
        self.friend.list[pid] = {ctime = this.time()}
        self.friend.len = self.friend.len + 1
        self:set_dirty()

        local data = social.get_data("get_friend_data", pid)
        if data then
            this.usersend(self.pid, "response_message", "social_add_friend_notice", {data = data})
        end

        add_subscribe(pid, self.pid)
    end
end

-- 删除好友
function udata:del_friend(pid)
    if (self.friend.list[pid] ~= nil) then
        self.friend.list[pid] = nil
        self.friend.len = self.friend.len - 1
        self:set_dirty()

        this.usersend(self.pid, "response_message", "social_del_friend_notice", {pid = pid})

        del_subscribe(pid, self.pid)
    end
end

-- 敌人判断
function udata:is_enemy(pid)
    if self.enemy.list[pid] then
        return true
    else
        return false
    end
end

-- 增加敌人
function udata:add_enemy(pid)
    if (self.enemy.list[pid] == nil) then
        self.enemy.list[pid] = {ctime = this.time()}
        self.enemy.len = self.enemy.len + 1
        self:set_dirty()

        add_subscribe(pid, self.pid)
    end
end

-- 删除敌人
function udata:del_enemy(pid)
    if (self.enemy.list[pid] ~= nil) then
        self.enemy.list[pid] = nil
        self.enemy.len = self.enemy.len - 1
        self:set_dirty()

        del_subscribe(pid, self.pid)
    end
end

-- 申请判断
function udata:has_applied(pid)
    if self.applicant.list[pid] then
        return true
    else
        return false
    end
end

-- 增加申请
function udata:add_applicant(pid)
    if (self.applicant.list[pid] == nil) then
        self.applicant.list[pid] = 1
        self.applicant.len = self.applicant.len + 1
        self:set_dirty()
    end
end

-- 删除申请
function udata:del_applicant(pid)
    if (self.applicant.list[pid] ~= nil) then
        self.applicant.list[pid] = nil
        self.applicant.len = self.applicant.len - 1
        self:set_dirty()
    end
end

-- 增加申请（待批准申请）
function udata:add_authorize(pid, message)
    if (self.authorize.list[pid] == nil) then
        local ctime = this.time()
        self.authorize.list[pid] = {ctime = ctime, msg = message}
        self.authorize.len = self.authorize.len + 1
        self:set_dirty()

        local data = social.get_data("get_friend_data", pid)
        data.msg = message
        data.ctime  = ctime
        this.usersend(self.pid, "response_message", "social_authorize_notice", {data = data})
    end
end

-- 删除申请（待批准申请）
function udata:del_authorize(pid)
    if (self.authorize.list[pid] ~= nil) then
        self.authorize.list[pid] = nil
        self.authorize.len = self.authorize.len - 1
        self:set_dirty()
    end
end

-- 判断朋友是否已满
function udata:friend_has_full()
    if self.friend.len >= MAX_FRIENDS_VALUE then
        return true
    else
        return false
    end
end

-- 判断敌人是否已满
function udata:enemy_has_full()
    if self.enemy.len >= MAX_ENEMIES_VALUE then
        return true
    else
        return false
    end
end

-- 判断申请是否已满
function udata:applicant_has_full()
    if self.applicant.len >= MAX_APPLICANTS_VALUE then
        return true
    else
        return false
    end
end

-- 判断申请是否已满（待批准申请）
function udata:authorize_has_full()
    if self.authorize.len >= MAX_APPLICANTS_VALUE then
        return true
    else
        return false
    end
end

-----------------------------------------------------------
--- 社交数据缓存
-----------------------------------------------------------
local evbuilder = require "common.cache.evbuilder"
local builder   = require "luamon.cachebuilder"

-- 社交数据加载模型
local loader = class("service.common.social.cache.loader", require("luamon.cache.loader"))

-- 数据加载逻辑
-- 1. 数据键值
function loader:load(key)
    local vdata = skynet.call(GLOBAL.SERVICE.DATACACHE, "lua", "get", "social", key)
    local udata = udata.new(key)
    if vdata then
        udata:unserialize(vdata)
    end
    return udata
end

-- 数据移除逻辑
-- 1. 数据键值
-- 2. 数据内容
local function remove(key, udata)
    if udata then
        if (udata:check_dirty()) then
            skynet.send(GLOBAL.SERVICE.DATACACHE, "lua", "set", "social", key, udata:serialize())
            udata:clear_dirty()
        end
    end
end

-- 构建缓存对象
cache = builder.new():capacity(5000)
               :evbuilder(evbuilder.new())
               :loader(loader.new())
               :removal(remove)
               :access_expired(86400)
               :build()

-----------------------------------------------------------
--- 服务业务接口
-----------------------------------------------------------
local command= {}


function command.load_data(source, type_list)
    local u1 = cache:get(source)
    if u1 then
        return social.get_all_friend_data(u1, type_list)
    end
end

-- 提交好友申请
-- 1. 申请来源
-- 2. 申请目标
-- 3. 申请留言
function command.submit_application(source, target, message)
    local u1 = cache:get(source)
    local u2 = cache:get(target)
    if (u1 == nil) or (u2 == nil) then
        return ERRCODE.COMMON_SYSTEM_ERROR
    end
    if source == target then
        return ERRCODE.COMMON_PARAMS_ERROR
    end
    -- 检查是否好友
    if u1:is_friend(target) then
        return ERRCODE.SOCIAL_ALREADY_FRIEND
    end
    -- 检查是否申请
    if u1:has_applied(target) then
        return ERRCODE.SOCIAL_ALREADY_APPLIED
    end
    -- 检查申请上限
    if u1:applicant_has_full() then
        return ERRCODE.SOCIAL_APPLIED_FULL
    end
    if u2:authorize_has_full() then
        return ERRCODE.SOCIAL_AUTHORIZE_FULL
    end
    -- 提交好友申请
    u1:add_applicant(target)
    u2:add_authorize(source, message)
    return 0
end

-- 同意好友申请
-- 1. 角色编号
-- 2. 目标编号
function command.agree_application(source, target)
    local u1 = cache:get(source)
    local u2 = cache:get(target)
    if (u1 == nil) or (u2 == nil) then
        return ERRCODE.COMMON_SYSTEM_ERROR
    end
    -- 检查是否申请
    if not u2:has_applied(source) then
        return ERRCODE.COMMON_PARAMS_ERROR
    end
    -- 检查好友容量
    if u1:friend_has_full() or u2:friend_has_full() then
        return ERRCODE.SOCIAL_FRIEND_FULL
    end
    -- 同意好友申请
    u1:del_authorize(target)
    u2:del_applicant(source)
    u1:del_enemy(target)
    u2:del_enemy(source)
    u1:add_friend(target)
    u2:add_friend(source)
    return 0
end

-- 拒绝好友申请
-- 1. 角色编号
-- 2. 目标编号
function command.reject_application(source, target)
    local u1 = cache:get(source)
    local u2 = cache:get(target)
    if (u1 == nil) or (u2 == nil) then
        return ERRCODE.COMMON_SYSTEM_ERROR
    end
    -- 检查是否申请
    if not u2:has_applied(source) then
        return ERRCODE.COMMON_PARAMS_ERROR
    end
    -- 拒绝好友申请
    u1:del_authorize(target)
    u2:del_applicant(source)
    return 0
end

-- 移除好友
-- 1. 角色编号
-- 2. 好友编号
function command.delete_friend(source, target)
    local u1 = cache:get(source)
    local u2 = cache:get(target)
    if (u1 == nil) or (u2 == nil) then
        return ERRCODE.COMMON_SYSTEM_ERROR
    end
    -- 检查是否好友
    if not u1:is_friend(target) then
        return ERRCODE.COMMON_PARAMS_ERROR
    end
    -- 移除指定好友
    u1:del_friend(target)
    u2:del_friend(source)
    return 0
end

-- 添加敌人
-- 1. 角色编号
-- 2. 敌人编号
function command.append_enemy(source, target)
    local u1 = cache:get(source)
    local u2 = cache:get(target)
    if (u1 == nil) or (u2 == nil) then
        return ERRCODE.COMMON_SYSTEM_ERROR
    end
    if source == target then
        return ERRCODE.COMMON_PARAMS_ERROR
    end
    -- 检查敌人容量
    if u1:enemy_has_full() then
        return ERRCODE.SOCIAL_ENEMY_FULL
    end
    -- 添加敌人（敌人无需双向确认）
    if u1:is_friend(target) then
        u1:del_friend(target)
        u2:del_friend(source)
    end
    u1:add_enemy(target)
    return 0
end

-- 移除敌人
-- 1. 角色编号
-- 2. 敌人编号
function command.remove_enemy(source, target)
    local u1 = cache:get(source)
    if (u1 == nil) then
        return ERRCODE.COMMON_SYSTEM_ERROR
    end
    u1:del_enemy(target)
    return 0
end

-----------------------------------------------------------
--- 服务回调接口
-----------------------------------------------------------
local server = {}

-- 服务启动通知
function server.on_init()
end

-- 服务结束通知
function server.on_exit()
    cache:clear()
end

-- 内部指令通知
-- 1. 指令来源
-- 2. 指令名称
-- 3. 执行参数
function server.on_command(source, cmd, ...)
    local fn = command[cmd]
    if fn then
        return fn(...)
    else
        ERROR("social : command[%s] not found!!!", cmd)
    end
end

-- 启动服务
service.start(server)
