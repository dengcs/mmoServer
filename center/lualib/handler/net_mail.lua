---------------------------------------------------------------------
--- 邮件模块相关业务逻辑
---------------------------------------------------------------------
local skynet = require "skynet"

---------------------------------------------------------------------
--- 内部变量/内部逻辑
---------------------------------------------------------------------

-- 去除没用的字段，不然协议不能编码
local function filter_mail(mail)
    mail.exdata = nil
    mail.mid = "邮件编号"
end

-- 去除没用的字段，不然协议不能编码
local function filter_mails(mails)
    for _,mail in pairs(mails or {}) do
        filter_mail(mail)
    end
end

---------------------------------------------------------------------
--- 内部指令处理逻辑
---------------------------------------------------------------------
local command = {}

-- 邮件新增通知
-- 1. 系统邮件序号
-- 2. 新增邮件列表
function command:mail_append_notice(mails)
    filter_mails(mails)

    -- 通知前端新增邮件
    self.response("mail_append_notice", { mails = mails })
end

---------------------------------------------------------------------
--- 网络请求处理逻辑
---------------------------------------------------------------------
local request = {}

-- 请求邮箱数据
function request:center_mail_access()
    local pid = self.user.pid
    -- 分页读取邮箱数据
    local ok, mails = skynet.call(GLOBAL.SERVICE_NAME.MAIL, "lua", "load", pid)

    if ok ~= 0 then
        mails = {}
    end
    filter_mails(mails)
    print("mails--", table.tostring(mails))
    self.response("mail_append_notice", { mails = mails })
end

-- 打开指定邮件(设置为已读标记)
function request:center_mail_open()
    local pid    = self.user.pid
    local ids    = self.proto.ids
    local ret       = 0
    local ret_ids   = nil
    local ok,result = skynet.call(GLOBAL.SERVICE_NAME.MAIL, "lua", "open", pid, ids)
    if ok == 0 then
        ret_ids = result
    else
        ret = ERRCODE.COMMON_SYSTEM_ERROR
    end
    self.response("center_mail_open_resp", { ret = ret, ids = ret_ids})
end

-- 移除指定邮件(设置为移除标记)
function request:center_mail_remove()
    local pid    = self.user.pid
    local ids    = self.proto.ids
    local ret       = 0
    local ret_ids   = {}
    local ok, result = skynet.call(GLOBAL.SERVICE_NAME.MAIL, "lua", "remove", pid, ids)
    if ok == 0 then
        ret_ids = result
    else
        ret = ERRCODE.COMMON_SYSTEM_ERROR
    end
    self.response("center_mail_remove_resp", { ret = ret , ids = ret_ids})
end

-- 领取邮件附件
function request:center_mail_receive()
    local pid    = self.user.pid
    local ids    = self.proto.ids
    local ret       = 0
    local ret_ids   = {}
    local ret_items = {}
    local ok, result = skynet.call(GLOBAL.SERVICE_NAME.MAIL, "lua", "receive", pid, ids)
    if ok == 0 then
        for _,v in pairs(result or {}) do
            table.insert(ret_ids, v.mid)
        end
    else
        ret = ERRCODE.COMMON_SYSTEM_ERROR
    end
    self.response("center_mail_receive_resp", { ret = ret, ids = ret_ids, attachments = ret_items })
end

---------------------------------------------------------------------
--- 内部事件处理逻辑
---------------------------------------------------------------------
local trigger = {}

-- 导出脚本模块
return { COMMAND = command, REQUEST = request, TRIGGER = trigger }
