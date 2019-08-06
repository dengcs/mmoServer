---------------------------------------------------------------------
--- 社交模块业务脚本
---------------------------------------------------------------------
local skynet = require "skynet"
local social = require "social"

local tb_insert   = table.insert

-------------------------------------------------------------------------------
--- 内部变量/内部逻辑
-------------------------------------------------------------------------------

---------------------------------------------------------------------
--- 网络请求处理逻辑
---------------------------------------------------------------------
local request = {}

function request:friend_access()
    local source = self.user.pid
    local ok, msg_data = skynet.call(GLOBAL.SERVICE_NAME.FRIEND, "lua", "load_data", source)
    if ok ~= 0 then
        msg_data = {}
    end
    self.response("friend_access_resp", msg_data)
end

-- 查找好友
function request:friend_search()
    local msg_data = {ret = 0}
    local name  = self.proto.name

    local pid = name:match("#(%d+)")
    repeat
        local datas = {}
        if pid then
            local data = social.get_friend_data(pid)
            if not data then
                msg_data.ret = ERRCODE.SOCIAL_NOT_ID
                break
            end

            tb_insert(datas, data)
        else
            if name:len() == 0 or name:len() > 30 then
                msg_data.ret = ERRCODE.COMMON_PARAMS_ERROR
                break
            end

            datas = social.get_friend_byName(name)
            if not datas then
                msg_data.ret = ERRCODE.SOCIAL_NOT_EXIST
                break
            end
        end

        msg_data.data = datas
    until(true)

    self.response("friend_search_resp", msg_data)
end

-- 提交好友申请
function request:friend_submit_application()
    local pid = tonumber(self.proto.pid)
    local msg = self.proto.msg
    local ret = 0
    repeat
        local source = self.user.pid
        local ok, retVal = skynet.call(GLOBAL.SERVICE_NAME.FRIEND, "lua", "submit_application", source, pid, msg)
        if ok ~= 0 then
            ret = ERRCODE.COMMON_SYSTEM_ERROR
            break
        end
        if retVal ~= 0 then
            ret = retVal
            break
        end
    until(true)
    self.response("friend_submit_application_resp", {ret = ret, pid = pid})
end

-- 同意好友申请
function request:friend_agree_application()
    local pid = tonumber(self.proto.pid)
    local ret = 0
    repeat
        local source = self.user.pid
        local ok, retVal = skynet.call(GLOBAL.SERVICE_NAME.FRIEND, "lua", "agree_application", source, pid)
        if ok ~= 0 then
            ret = ERRCODE.COMMON_SYSTEM_ERROR
            break
        end
        if retVal ~= 0 then
            ret = retVal
            break
        end
    until(true)
    self.response("friend_agree_application_resp", {ret = ret, pid = pid})
end

-- 拒绝好友申请
function request:friend_reject_application()
    local pid = tonumber(self.proto.pid)
    local ret = 0
    repeat
        local source = self.user.pid
        local ok, retVal = skynet.call(GLOBAL.SERVICE_NAME.FRIEND, "lua", "reject_application", source, pid)
        if ok ~= 0 then
            ret = ERRCODE.COMMON_SYSTEM_ERROR
            break
        end
        if retVal ~= 0 then
            ret = retVal
            break
        end
    until(true)
    self.response("friend_reject_application_resp", {ret = ret, pid = pid})
end

-- 移除好友
function request:friend_delete()
    local pid = tonumber(self.proto.pid)
    local ret = 0
    repeat
        local source = self.user.pid
        local ok, retVal = skynet.call(GLOBAL.SERVICE_NAME.FRIEND, "lua", "delete_friend", source, pid)
        if ok ~= 0 then
            ret = ERRCODE.COMMON_SYSTEM_ERROR
            break
        end
        if retVal ~= 0 then
            ret = retVal
            break
        end
    until(true)
    self.response("friend_delete_resp", {ret = ret, pid = pid})
end

-- 添加敌人
function request:friend_append_enemy()
    local pid = tonumber(self.proto.pid)
    local msg_data = {ret = 0}
    repeat
        local source = self.user.pid
        local ok, retVal = skynet.call(GLOBAL.SERVICE_NAME.FRIEND, "lua", "append_enemy", source, pid)
        if ok ~= 0 then
            ret = ERRCODE.COMMON_SYSTEM_ERROR
            break
        end
        if retVal ~= 0 then
            ret = retVal
            break
        end

        msg_data.data = social.get_friend_data(pid)
    until(true)
    self.response("friend_append_enemy_resp", msg_data)
end

-- 移除敌人
function request:friend_remove_enemy()
    local pid = tonumber(self.proto.pid)
    local ret = 0
    repeat
        local source = self.user.pid
        local ok, retVal = skynet.call(GLOBAL.SERVICE_NAME.FRIEND, "lua", "remove_enemy", source, pid)
        if ok ~= 0 then
            ret = ERRCODE.COMMON_SYSTEM_ERROR
            break
        end
        if retVal ~= 0 then
            ret = retVal
            break
        end
    until(true)
    self.response("friend_remove_enemy_resp", {ret = ret, pid = pid})
end

---------------------------------------------------------------------
--- 内部指令处理逻辑
---------------------------------------------------------------------
local command = {}

function command:social_update(pid, name, value)
    social.update(pid, {[name] = value})
end
---------------------------------------------------------------------
--- 内部事件处理逻辑
---------------------------------------------------------------------
local trigger = {}

-- 导出业务模块
return { COMMAND = command, REQUEST = request, TRIGGER = trigger }
