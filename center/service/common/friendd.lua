---------------------------------------------------------------------
--- 好友服务
---------------------------------------------------------------------
local service   = require "factory.service"
local skynet    = require "skynet"
local db_friend	= require "db.mongo.friend"
local social    = require "social"

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

-- 好友数据模型
local udata = class("udata")

-- 构建模型实例
-- 1. 角色编号
function udata.ctor(pid)
    self.dirty              = false                         -- 数据脏标记
    self.pid                = pid                           -- 角色编号
    self.friend             = { len = 0, list = {} }        -- 好友信息
    self.enemy              = { len = 0, list = {} }        -- 敌人信息
    self.applicant          = { len = 0, list = {} }        -- 申请信息（申请成为目标好友）
    self.authorize          = { len = 0, list = {} }        -- 申请信息（目标申请等待批准）
end

-- 序列化
function udata:serialize()
    local vdata =
    {
        pid             = self.pid,
        friend          = self.friend,
        enemy           = self.enemy,
        applicant       = self.applicant,
        authorize       = self.authorize,
    }
    return vdata
end

-- 反序列化
function udata:unserialize(vdata)
    if vdata then
        self.pid                = vdata.pid
        self.friend             = vdata.friend
        self.enemy              = vdata.enemy
        self.applicant          = vdata.applicant
        self.authorize          = vdata.authorize
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

        local data = social.get_friend_data(pid)
        if data then
            this.usersend(self.pid, "response_message", "social_add_friend_notice", {data = data})
        end
    end
end

-- 删除好友
function udata:del_friend(pid)
    if (self.friend.list[pid] ~= nil) then
        self.friend.list[pid] = nil
        self.friend.len = self.friend.len - 1
        self:set_dirty()

        this.usersend(self.pid, "response_message", "social_del_friend_notice", {pid = pid})
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
    end
end

-- 删除敌人
function udata:del_enemy(pid)
    if (self.enemy.list[pid] ~= nil) then
        self.enemy.list[pid] = nil
        self.enemy.len = self.enemy.len - 1
        self:set_dirty()
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

        local data = social.get_friend_data(pid)
        if data then
            data.msg = message
            data.ctime  = ctime
            this.usersend(self.pid, "response_message", "social_authorize_notice", {data = data})
        end
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
--- 好友缓存对象
-----------------------------------------------------------

local cache = {}

function cache:init()
    self.queue          = {}
    self.cache_count  	= 0
    self.cache_max  	= 1000
end

function cache:load(pid)
    local vdata = db_friend.get(pid)
    if vdata then
        local tdata = udata.new(pid)
        tdata:unserialize(vdata)
        return tdata
    end
end

function cache:get(pid)
    local tdata = self.queue[pid]
    if not tdata then
        tdata = self:load(pid)
        self.queue[pid] = tdata
        self.cache_count = self.cache_count + 1
    end
    return tdata
end

function cache:save(pid, clean)
    local tdata = self.queue[pid]
    if tdata then
        if tdata:check_dirty() then
            db_friend.set(pid, tdata:serialize())
            tdata:clear_dirty()
        end

        if clean then
            if self.cache_count > self.cache_max then
                self.queue[pid] = nil
                self.cache_count = self.cache_count - 1
            end
        end
    end
end

function cache:save_all()
    for pid in pairs(self.queue) do
        self:save(pid)
    end
end

-----------------------------------------------------------
--- 服务业务接口
-----------------------------------------------------------
local command= {}


function command.load_data(source)
    local u1 = cache:get(source)
    if u1 then
        return social.get_all_friend_data(u1)
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
        return ERRCODE.FRIEND_ALREADY_FRIEND
    end
    -- 检查是否申请
    if u1:has_applied(target) then
        return ERRCODE.FRIEND_ALREADY_APPLIED
    end
    -- 检查申请上限
    if u1:applicant_has_full() then
        return ERRCODE.FRIEND_APPLIED_FULL
    end
    if u2:authorize_has_full() then
        return ERRCODE.FRIEND_AUTHORIZE_FULL
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
        return ERRCODE.FRIEND_FRIEND_FULL
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
        return ERRCODE.FRIEND_ENEMY_FULL
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
function server.init_handler()
    cache:init()
    local function save_all()
        cache:save_all()
    end
    this.schedule(save_all , 60*60, SCHEDULER_FOREVER)
end

-- 服务结束通知
function server.exit_handler()
    cache:save_all()
end

-- 内部指令通知
-- 1. 指令来源
-- 2. 指令名称
-- 3. 执行参数
function server.command_handler(source, cmd, ...)
    local fn = command[cmd]
    if fn then
        return fn(...)
    else
        ERROR("social : command[%s] not found!!!", cmd)
    end
end

-- 启动服务
service.start(server)
