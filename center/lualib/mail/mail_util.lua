local skynet = require "skynet"

local mail_util = {}

-- 系统普通邮件死亡日
local SYS_MAIL_DEAD_DAY = 15
-- 系统附件邮件死亡日
local SYS_ATTACH_MAIL_DEAD_DAY = 30
-- 最大附件数量
local MAX_ATTACHEMENT_NUM = 8

-- 生成一份邮件
-- @param category - 1 好友 - 2 系统
-- @param from  -> {pid = , name =, portrait=}  pid 名字 图标
-- @param title 标题
-- @param content 内容
-- @param attachments {{id =, count =}}附件
-- @param deadline 死亡时间 秒
-- @param args 附带参数
function mail_util.gen_mail(category, from, title, content, attachments, deadline, args)
    local now = this.time()
    local mail = {}
    mail.timestamp = now
    mail.category = category
    mail.from = from
    mail.title = title
    mail.content = content
    mail.attachments = attachments
    mail.deadline = now + deadline
    mail.args = args
    return mail
end

-- 生成一份系统邮件
function mail_util.gen_sys_mail(title, content, attachments, args)
    local attach_num = 0
    if attachments then
        attach_num = #attachments
        if attach_num > MAX_ATTACHEMENT_NUM then
            LOG_ERROR("mail attachment num(%d) too large",#attachments)
            return nil
        end
    end
    local deadline = SYS_MAIL_DEAD_DAY * 24 * 3600
    if attach_num > 0 then
        deadline = SYS_ATTACH_MAIL_DEAD_DAY * 24 * 3600
    end
    return mail_util.gen_mail(
        1,
        {
            pid = "0"
        },
        title,
        content,
        attachments,
        deadline,
        args
    )
end

-- 生成一份标题或内容可以格式化的系统邮件
-- @content_id 邮件内容配置id,字符类型
-- 配置格式"fsd{aa.bb}dd"
-- @params 格式{aa={...},bb={...}}
-- @attachments 附件
function mail_util.generate_sys_mail(content_id, params, attachments, args)
    local eMailCfg = this.sheetdata("ConfigEmailContent", content_id)
    if not eMailCfg then
        LOG_ERROR("mail ConfigEmailContent id[%s] not exist",content_id)
        return
    end
    
    local newTitle = eMailCfg.Title
    local newContent = eMailCfg.Des
    
    if params then
        newTitle = newTitle:table_format(params)
        newContent = newContent:table_format(params)
    end
    
    return mail_util.gen_sys_mail(newTitle,newContent,attachments,args)
end

-- 发送一份系统邮件
function mail_util.send_sys_mail(pid, title, content, attachments, args)
    local mail = mail_util.gen_sys_mail(title, content, attachments, args)
    skynet.send(GAME.SERVICE.MAIL, "lua", "send", pid, mail)
end

-- 发送一份格式化邮件
function mail_util.send_mail(pid, content_id, params, attachments, args)
    local mail = mail_util.generate_sys_mail(content_id, params, attachments, args)
    skynet.send(GAME.SERVICE.MAIL, "lua", "send", pid, mail)
end

return mail_util