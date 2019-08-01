---------------------------------------------------------------------
--- 邮件服务
---------------------------------------------------------------------
local skynet   	= require "skynet"
local service  	= require "factory.service"
local db_mail	= require "db.mongo.mail"

local tb_insert = table.insert

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
function MailBox:ctor(pid)
	self.pid   	= pid
	self.maxId	= 0
	self.mails 	= {}
end

-- 邮箱迭代
function MailBox:pairs()
	return pairs(self.mails)
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
	if mid > self.maxId then
		self.maxId = mid
	end

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

-- 序列号
local seqNo = 0

local function allocId()
	seqNo = seqNo + 1
	if seqNo >= 1000000 then
		seqNo = 0
	end
	local xtime = this.time()

	return (xtime << 20) | seqNo
end

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
		local insert_id = allocId()
		local data =
		{
			pid			= pid,
			mid 		= insert_id,
			category 	= category,
			source		= source,
			subject		= subject,
			content		= content,
			attachments	= attachments,
			status		= status,
			exdata		= exdata,
			ctime		= ctime,
			deadline	= deadline,
		}
		local ok = db_mail.insert(data)
		if ok then
			return insert_id
		else
			return nil
		end
	end,

	-- 更新邮件状态
	-- 1. 角色编号
	-- 2. 邮件编号
	-- 3. 邮件状态
	['update'] = function(pid, mid, status)
		local query = {pid = pid, mid = mid}
		local data	= {status = status}
		return db_mail.set(query, data)
	end,

	-- 加载角色邮件
	-- 1. 角色编号
	['select'] = function(pid)
		-- 邮件加载方法
		local query =
		{
			pid 		= pid,
			status		= {['$lt'] = ESYMBOL.REMOVED},
			['$or'] = {{deadline = 0}, {deadline = {['$gt'] = this.time()}}}
		}
		return db_mail.keys(query)
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
local function deliver(pid, category, source, subject, content, attachments, exdata, delay)
	-- 选择邮箱
	local mailbox = madmin
	if pid ~= 0 then
		mailbox = onlines[pid]
	end
	-- 投递邮件
	local status   = 0
	local ctime    = this.time()
	local deadline = 0
	if delay then
		deadline = ctime + delay
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
function command.load(pid)
	-- 获取角色邮箱
	local mailbox = onlines[pid]
	if mailbox == nil then
		mailbox = MailBox.new(pid)
		onlines[pid] = mailbox
		-- 加载用户邮件
		for _, v in pairs(db.select(pid)) do
			mailbox:add(v.mid, v.category, v.source, v.subject, v.content, v.attachments, v.status, v.exdata, v.ctime, v.deadline)
		end
		-- 投递系统邮件
		local ctime = this.time()
		local mails = {}
		for _, v in madmin:pairs() do
			repeat
				-- 过滤已投递系统邮件
				if v.mid <= mailbox.sid then
					break
				end
				-- 过滤已过期系统邮件
				if (v.deadline ~= 0) and (v.deadline < ctime) then
					break
				end
				tb_insert(mails, v)
			until(true)
		end

		for _, v in pairs(mails) do
			deliver(pid, v.category, v.source, v.subject, v.content, v.attachments, v.exdata, duration)
		end
	end
	-- 邮件分页返回
	local mails   = {}
	for _, mail in mailbox:pairs() do
		tb_insert(mails, mail)
	end
	return mails
end

-- 卸载邮箱(角色登出时触发)
-- 1. 角色编号
function command.unload(pid)
	onlines[pid] = nil
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
			if mailbox then
				local mid	= deliver(pid, category, source, subject, content, attachments, exdata, duration)
				local mail 	= mailbox:get(mid)
				if mail then
					this.usersend(pid, "mail_append_notice", { mail })
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
		if mail and ((mail.status & ESYMBOL.READ) == 0) then
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
		return
	end
	local ctime = this.time()
	-- 变更邮件状态
	local retval = {}
	for _, mid in pairs(mids) do
		local mail = mailbox:get(mid)
		if mail and ((mail.status & ESYMBOL.RECEIVE) == 0) then
			if mail.deadline >= ctime then
				if mail.attachments and next(mail.attachments) then
					-- 记录可领取邮件
					tb_insert(retval, { mid = mail.mid, attachments = mail.attachments })
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
				this.usersend(pid, "mail_append_notice", { m })
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
function server.init_handler(config)
	madmin = MailBox.new(0, 0)
	for _, v in pairs(db.select(0) or {}) do
		madmin:add(v.mid, v.category, v.source, v.subject, v.content, v.attachments, v.status, v.exdata, v.ctime, v.deadline)
	end
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
		LOG_ERROR("mail : command[%s] not found!!!", cmd)
	end
end

-- 启动组队服务
service.start(server)