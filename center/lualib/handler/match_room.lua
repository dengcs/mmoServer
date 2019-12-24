--
-- 房间战组队
--
local skynet    = require "skynet"
local social    = require "social"

local handler = {}
local REQUEST = {}

-----------------------------------------------------------
-- 请求服务接口
-----------------------------------------------------------

-- 创建房间
function REQUEST:room_create()
    local resp = "room_create_resp"
    local ret = 0
    local pid       = self.user.pid
    local channel   = self.proto.channel

    repeat
        local vdata = social.get_user_data(pid)
        if vdata == nil then
            ret = ERRCODE.COMMON_FIND_ERROR
            break
        end

        vdata.agent = skynet.self()
        local ok,ret_code = skynet.call(GLOBAL.SERVICE_NAME.ROOM, "lua", "on_create", channel, vdata)
        if ok ~= 0 then
            ret = ERRCODE.COMMON_SYSTEM_ERROR
            break
        end

        ret = ret_code
    until(true)

    local ret_msg = {ret = ret}
    self.response(resp, ret_msg)
end

-- 快速加入
function REQUEST:room_qkjoin()
	local resp = "room_qkjoin_resp"
    local ret = 0

    local ret_msg = {ret = ret}
    self.response(resp, ret_msg)
end

-- 邀请好友
function REQUEST:room_invite()
	local resp = "room_invite_resp"
    local ret = 0

    local ret_msg = {ret = ret}
    self.response(resp, ret_msg)
end

-- 重新开始
function REQUEST:room_restart()
    local ret = 0

    local pid       = self.user.pid
    local channel   = self.proto.channel
    local tid       = self.proto.tid

    repeat
        local ok,ret_code = skynet.call(GLOBAL.SERVICE_NAME.ROOM, "lua", "on_restart", channel, tid, pid)

        if ok ~= 0 then
            ret = ERRCODE.COMMON_SYSTEM_ERROR
            break
        end

        ret = ret_code
    until(true)

    self.response("room_restart_resp", {ret = ret})
end

-- 取消匹配
function REQUEST:room_cancel()
    local resp = "room_cancel_resp"
    local ret = 0

    local ret_msg = {ret = ret}
    self.response(resp, ret_msg)
end

-- 离开房间
function REQUEST:room_quit()
    local resp = "room_quit_resp"
    local ret = 0

    local ret_msg = {ret = ret}
    self.response(resp, ret_msg)
end

-- '请求/命令' - 注册
handler.REQUEST = REQUEST
return handler
