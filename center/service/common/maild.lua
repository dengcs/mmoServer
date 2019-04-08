---------------------------------------------------------------------
--- 邮件服务
---------------------------------------------------------------------
local service  = require "factory.service"
local database = require "common.database"
local skynet   = require "skynet.manager"
local mysqlaux = require "skynet.mysqlaux.c"

---------------------------------------------------------------------
--- 邮箱数据模型
---------------------------------------------------------------------
local MailBox = class("mailbox")

-- 邮件类型枚举
local ECATEGORY =
{
	NORMAL   = 1,           -- 普通邮件
	SYSTEM   = 2,           -- 系统邮件
}

-- 邮件状态标记
local ESYMBOL =
{
	READ     = 1,           -- 邮件已读标记
	RECEIVE  = 2,           -- 附件已领标记
	REMOVED  = 4,           -- 邮件删除标记
}

-- 构建邮箱对象
-- 1. 系统邮件编号
function MailBox:ctor(pid, sid)
	self.pid   = pid
	self.sid   = sid
	self.mails = {}
end

-- 邮箱迭代
function MailBox:iterator()
	local index = nil
	local value = nil
	return function()
		local i, v = next(self.mails, index)
		if v == nil then
			return nil
		else
			index = i
			value = v
			return index, value
		end
	end
end

-- 新增邮件
-- 1. 邮件编号
-- 2. 邮件类型
-- 3. 邮件来源
-- 4. 邮件标题
-- 5. 邮件正文
-- 6. 附件信息
-- 7. 邮件状态
-- 8. 附加信息
-- 9. 创建时间
-- 0. 到期时间
function MailBox:add(mid, category, source, subject, content, attachments, status, exdata, ctime, deadline)
	self.mails[mid] =
	{
		mid         = mid,
		category    = category,
		source      = source,
		subject     = subject,
		content     = content,
		attachments = attachments,
		status      = status,
		exdata      = exdata,
		ctime       = ctime,
		deadline    = deadline,
	}
	return self.mails[mid]
end

-- 获取邮件
-- 1. 邮件编号
function MailBox:get(mid)
	return self.mails[mid]
end

-- 移除邮件
-- 1. 邮件编号
function MailBox:del(mid)
	local mail = self.mails[mid]
	if mail then
		self.mails[mid] = nil
	end
	return mail
end

---------------------------------------------------------------------
--- 内部变量/内部逻辑
---------------------------------------------------------------------
local madmin   = nil    -- 系统邮箱
local onlines  = {}     -- 在线邮箱

-- 默认邮件生命时长(秒)
local duration = 604800

-- 邮件数据操作逻辑
local db =
{
	-- 新增邮件记录
	--  1. 角色编号(角色编号为零表示系统邮件)
	--  2. 邮件类型
	--  3. 邮件来源
	--  4. 邮件标题
	--  5. 邮件正文
	--  6. 附件信息
	--  7. 邮件状态
	--  8. 附加信息
	--  9. 创建时间
	-- 10. 到期时间
	['insert'] = function(pid, category, source, subject, content, attachments, status, exdata, ctime, deadline)
		local sql = string.format("INSERT INTO mail(pid, category, source, subject, content, attachments, status, exdata, ctime, deadline) VALUES(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
				pid,
				category,
				source,
				mysqlaux.quote_sql_str(subject),
				mysqlaux.quote_sql_str(content),
				mysqlaux.quote_sql_str(skynet.packstring(attachments)),
				status,
				mysqlaux.quote_sql_str(skynet.packstring(exdata)),
				ctime,
				deadline)
		local ret = database.set("db.mysql", sql)
		if ret then
			return ret.insert_id
		else
			return nil
		end
	end,

	-- 更新邮件状态
	-- 1. 角色编号
	-- 2. 邮件编号
	-- 3. 邮件状态
	['update'] = function(pid, mid, status)
		local sql = string.format("UPDATE mail SET status = %s WHERE pid = %s AND mid = %s", status, pid, mid)
		return database.exec("db.mysql", sql)
	end,

	-- 加载角色邮件
	-- 1. 角色编号
	['select'] = function(pid)
		-- 邮件加载方法
		local sql = string.format("SELECT * FROM mail WHERE pid = %s AND (status & %s) = 0 AND (deadline = 0 OR deadline > %s)",
				pid,
				ESYMBOL.REMOVED,
				this.time())
		return database.exec("db.mysql", sql)
	end,
}

-- 邮件投递操作(角色编号为零表示系统邮箱)
-- 1. 角色编号
-- 2. 邮件类型
-- 3. 邮件来源
-- 4. 邮件标题
-- 5. 邮件正文
-- 6. 附件信息
-- 7. 附加信息
-- 8. 生存时长
local function deliver(pid, category, source, subject, content, attachments, exdata, duration)
	-- 选择邮箱
	local mailbox = madmin
	if pid ~= 0 then
		mailbox = onlines[pid]
	end
	-- 投递邮件
	local status   = 0
	local ctime    = this.time()
	local deadline = 0
	if duration ~= nil then
		deadline = ctime + duration
	end
	local mid = db.insert(pid, category, source, subject, content, (attachments or {}), status, (exdata or {}), ctime, deadline)
	if mailbox then
		mailbox:add(mid, category, source, subject, content, (attachments or {}), status, (exdata or {}), ctime, deadline)
	end
	return mid
end

---------------------------------------------------------------------
--- 邮件服务接口
---------------------------------------------------------------------
local command = {}

-- 加载邮箱(角色登录时触发)
-- 1. 系统邮件编号
-- 2. 角色编号
-- 3. 邮件偏移
-- 4. 邮件数量
function command.load(sid, pid)
	-- 获取角色邮箱
	local mailbox = onlines[pid]
	if mailbox == nil then
		mailbox = MailBox.new(pid, sid)
		onlines[pid] = mailbox
		-- 加载用户邮件
		for _, v in pairs(db.select(pid)) do
			mailbox:add(v.mid, v.category, v.source, v.subject, v.content, skynet.unpack(v.attachments), v.status, skynet.unpack(v.exdata), v.ctime, v.deadline)
		end
		-- 投递系统邮件
		local ctime = this.time()
		local maxid = 0
		local mails = {}
		for _, v in madmin:iterator() do
			repeat
				-- 过滤已投递系统邮件
				if v.mid <= mailbox.sid then
					break
				end
				-- 过滤已过期系统邮件
				if (v.deadline ~= 0) and (v.deadline < ctime) then
					break
				end
				-- 记录可投递系统邮件
				if maxid <= v.mid then
					maxid = v.mid
				end
				table.insert(mails, v)
			until(true)
		end
		if next(mails) then
			if maxid > 0 then
				mailbox.sid = maxid
			end
			for _, v in pairs(mails) do
				deliver(pid, v.category, v.source, v.subject, v.content, v.attachments, v.exdata, duration)
			end
		end
	end
	-- 邮件分页返回
	local mails   = {}
	for _, mail in mailbox:iterator() do
		table.insert(mails, mail)
	end
	return { sid = mailbox.sid, mails = mails }
end

-- 卸载邮箱(角色登出时触发)
-- 1. 角色编号
function command.unload(pid)
	local mailbox = onlines[pid]
	if not mailbox then
		return nil
	else
		onlines[pid] = nil
		return mailbox.sid
	end
end

-- 投递邮件(普通邮件)
-- 1. 角色列表
-- 2. 邮件类型
-- 3. 邮件来源
-- 4. 邮件标题
-- 5. 邮件正文
-- 6. 附件信息
-- 7. 附加信息
function command.deliver(pids, category, source, subject, content, attachments, exdata)
	for _, pid in pairs(pids) do
		repeat
			-- 防止投递系统邮箱
			if pid == 0 then
				break
			end
			-- 投递指定用户邮箱
			local mailbox = onlines[pid]
			local mid     = deliver(pid, category, source, subject, content, attachments, exdata, duration)
			if mailbox then
				local mail = mailbox:get(mid)
				if mail then
					this.usersend(pid, "mail_append_notice", mailbox.sid, { mail })
				end
			end
		until(true)
	end
	return 0
end

-- 打开邮件(仅仅变更邮件状态)
-- 1. 角色编号
-- 2. 邮件列表
function command.open(pid, mids)
	-- 获取角色邮箱
	local mailbox = onlines[pid]
	if mailbox == nil then
		return ERRCODE.COMMON_SYSTEM_ERROR
	end
	-- 变更邮件状态
	for _, mid in pairs(mids) do
		local mail = mailbox:get(mid)
		if (mail ~= nil) and ((mail.status & ESYMBOL.READ) == 0) then
			mail.status = (mail.status | ESYMBOL.READ)
			db.update(pid, mid, mail.status)
		end
	end
	return 0
end

-- 领取附件(仅仅变更邮件状态)
-- 1. 角色编号
-- 2. 邮件列表
function command.receive(pid, mids)
	-- 获取角色邮箱
	local mailbox = onlines[pid]
	if mailbox == nil then
		return ERRCODE.COMMON_SYSTEM_ERROR
	end
	local ctime = this.time()
	-- 变更邮件状态
	local retval = {}
	for _, mid in pairs(mids) do
		local mail = mailbox:get(mid)
		if (mail ~= nil) and ((mail.status & ESYMBOL.RECEIVE) == 0) then
			if mail.deadline >= ctime then
				if next(mail.attachments) then
					-- 记录可领取邮件
					table.insert(retval, { mid = mail.mid, attachments = mail.attachments })
					-- 删除可领取邮件
					mail.status = (mail.status | ESYMBOL.RECEIVE | ESYMBOL.REMOVED)
					mailbox:del(mid)
					db.update(pid, mid, mail.status)
				end
			end
		end
	end
	return retval
end

-- 移除邮件(设置邮件移除标记)
-- 1. 角色编号
-- 2. 邮件列表
function command.remove(pid, mids)
	-- 获取角色邮箱
	local mailbox = onlines[pid]
	if mailbox == nil then
		return ERRCODE.COMMON_SYSTEM_ERROR
	end
	-- 移除指定邮件
	for _, mid in pairs(mids) do
		local mail = mailbox:del(mid)
		if (mail ~= nil) then
			mail.status =  (mail.status | ESYMBOL.REMOVED)
			db.update(pid, mid, mail.status)
		end
	end
	return 0
end

-- 增加系统邮件
-- 1. 邮件标题
-- 2. 邮件正文
-- 3. 附件信息
-- 4. 附加信息
-- 5. 生存时长(秒)
function command.gm_append_mail(subject, content, attachments, exdata, ttl)
	local mail = madmin:get(deliver(0, ECATEGORY.SYSTEM, 0, subject, content, attachments, exdata, ttl))
	if mail ~= nil then
		-- 推送在线邮箱
		for pid, mailbox in pairs(onlines) do
			local m = mailbox:get(deliver(pid, mail.category, 0, subject, content, attachments, exdata, duration))
			if m ~= nil then
				mailbox.sid = math.max(m.mid, mail.mid)
				this.usersend(pid, "mail_append_notice", mailbox.sid, { m })
			end
		end
	end
	return 0
end

-- 删除系统邮件(设置邮件移除标记)
-- 1. 邮件列表
function command.gm_delete_mail(mids)
	for _, mid in pairs(mids) do
		local mail = madmin:del(mid)
		if (mail ~= nil) then
			mail.status = (mail.status | ESYMBOL.REMOVED)
			db.update(0, mid, mail.status)
		end
	end
	return 0
end

---------------------------------------------------------------------
--- 服务回调接口
---------------------------------------------------------------------
local server = {}

-- 服务构造通知
-- 1. 构造配置
function server.on_init(config)
	madmin = MailBox.new(0, 0)
	for _, v in pairs(db.select(0)) do
		madmin.sid = math.max(madmin.sid, v.mid)
		madmin:add(v.mid, v.category, v.source, v.subject, v.content, skynet.unpack(v.attachments), v.status, skynet.unpack(v.exdata), v.ctime, v.deadline)
	end
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
		ERROR("mail : command[%s] not found!!!", cmd)
	end
end

-- 启动组队服务
service.start(server)