---------------------------------------------------------------------
--- 邮件模块相关业务逻辑
---------------------------------------------------------------------
local skynet = require "skynet"

---------------------------------------------------------------------
--- 内部变量/内部逻辑
---------------------------------------------------------------------

---------------------------------------------------------------------
--- 内部指令处理逻辑
---------------------------------------------------------------------
local command = {}

-- 邮件新增通知
-- 1. 系统邮件序号
-- 2. 新增邮件列表
function command:chat_msg_notice(data)
    self.response("chat_msg_notice", data)
end

---------------------------------------------------------------------
--- 网络请求处理逻辑
---------------------------------------------------------------------
local request = {}

function request:chat_msg()
    local ret = 0
    repeat
        local params =
        {
            source      = self.user.pid,
            channel     = self.proto.channel,
            receive_pid = tonumber(self.proto.receive_pid),
            content     = self.proto.content,
        }
        local ok, retVal = skynet.call(GLOBAL.SERVICE_NAME.CHAT, "lua", "send_msg", params)
        if ok ~= 0 then
            ret = ERRCODE.COMMON_SYSTEM_ERROR
            break
        end

        if retVal ~= 0 then
            ret = retVal
            break
        end
    until(true)
    self.response("chat_msg_resp", { ret = ret })
end

---------------------------------------------------------------------
--- 内部事件处理逻辑
---------------------------------------------------------------------
local trigger = {}

-- 导出脚本模块
return { COMMAND = command, REQUEST = request, TRIGGER = trigger }
