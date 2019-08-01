local skynet    = require "skynet"
--local json      = require "cjson"

local mail = {}

-- -- 普通邮件死亡日
-- local SYS_MAIL_DEAD_DAY = 15
-- -- 附件邮件死亡日
-- local SYS_ATTACH_MAIL_DEAD_DAY = 30
-- 最大附件数量
local MAX_ATTACHEMENT_NUM = 8

-- 生成一份邮件
-- @param category - 1 普通 - 2 系统
-- @param source  -> {pid = , name =, portrait=}  pid 名字 图标
-- @param subject 标题
-- @param content 内容
-- @param attachments {{id =, count =}}附件
-- @param args 附带参数
function mail.gen_mail(category, source, subject, content, attachments, args)
    local data = {}
    data.category = category
    data.source = source
    data.subject = subject
    data.content = content
    data.attachments = attachments
    data.args = args
    return data
end

-- 生成一份普通邮件
function mail.gen_original_mail(category, subject, content, attachments, args)
    local attach_num = 0
    if attachments then
        attach_num = #attachments
        if attach_num > MAX_ATTACHEMENT_NUM then
            LOG_ERROR("mail attachment num(%d) too large",#attachments)
            return nil
        end
    end
    return mail.gen_mail(
        category,
        {
            pid = 0
        },
        subject,
        content,
        attachments,
        args
    )
end

---- 生成一份标题或内容可以格式化的系统邮件
---- @content_id 邮件内容配置id,字符类型
---- @attachments 附件
--function mail.generate_format_mail(content_id, attachments, content_params, title_params, args)
--    local subject = {id = content_id, params = title_params}
--    local content = {id = content_id, params = content_params}
--    subject = json.encode(subject)
--    content = json.encode(content)
--
--    return mail.gen_original_mail(1, subject, content, attachments, args)
--end

function mail.send_mail(pid, data)
    assert(data)
    local pids = IS_TABLE(pid) and pid or {pid}
    local exdata = {args = data.args}
    
    skynet.send(GLOBAL.SERVICE_NAME.MAIL, "lua", "deliver", pids, data.category, data.source, data.subject, data.content, data.attachments, exdata)
end

-- 发送一份原始邮件（标题和内容都是原始的内容，不会替换）
function mail.deliver_mail(pid, title, content, attachments, args)
    local data = mail.gen_original_mail(2, title, content, attachments, args)
    mail.send_mail(pid, data)
end

---- 发送一份格式化邮件（标题和内容有格式）
--function mail.deliver_mail(pid, content_id, attachments, content_params, title_params, args)
--    local data = mail.generate_format_mail(content_id, attachments, content_params, title_params, args)
--    mail.send_mail(pid, data)
--end

return mail