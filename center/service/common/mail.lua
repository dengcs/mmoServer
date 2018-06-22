---------------------------------------------------------------------
--- 邮件管理服务
---------------------------------------------------------------------
local service  = require "service"
local skynet   = require "skynet.manager"
local mysqlaux = require "skynet.mysqlaux.c"
local timer    = require "utils.timer"
local database = require "common.database"

---------------------------------------------------------------------
--- 邮箱模型
---------------------------------------------------------------------
local MailBox = {}
MailBox.__index = MailBox

-- 邮件类型枚举
local ECATEGORY = 
{
	NORMAL   = 1,		-- 普通邮件
	SYSTEM   = 2,		-- 系统邮件
	FACTION  = 3,		-- 车队邮件
}

-- 邮件状态枚举
local ESTATUS = 
{
	UNREAD   = 1,		-- 未读状态
	READ     = 2,		-- 已读状态
	RECEIVED = 3,		-- 已经领取
}

-- 通知类型枚举
local ENOTICE = 
{
	APPEND   = 1,		-- 新增邮件
	DELETE   = 2,		-- 删除邮件
	UPDATE   = 3,		-- 邮件更新
}

-- 通知客户端操作类型
local MAIL_EVENT = {
    NEW = 1, -- 新邮件
    DEL = 2, -- 删除
}

-- 构建邮箱
-- 1. 角色编号
-- 2. 邮件标记
function MailBox.new()
	local mailbox = 
	{
		mid = 0, -- 最大邮件id
		mails = {},
	}
	return setmetatable(mailbox, MailBox)
end

-- 新增邮件（仅将邮件记录加入邮箱）
-- 1. 邮件编号
-- 2. 邮件类型
-- 3. 邮件来源
-- 4. 邮件标题
-- 5. 邮件正文
-- 6. 附件信息({{id, count}, ...})
-- 7. 创建时间
-- 8. 到期时间
-- 9. 邮件状态
function MailBox:insert(sid, category, from, title, content, attachments, timestamp, deadline, state)
	-- 记录最大邮件ID
	local cpsid = tonumber(sid)
	if cpsid > self.mid then
		self.mid = cpsid
	end

	sid = tostring(sid)
	assert(not self.mails[sid])
	self.mails[sid] = 
	{
		sid          = sid,
		category    = category,
		from      = from,
		state      = state,
		title     = title,
		content     = content,
		attachments = attachments,
		timestamp    = timestamp,
		deadline    = deadline,
	}
	return self.mails[sid]
end

-- 删除邮件（仅从邮箱删除邮件记录）
-- 1. 邮件编号
function MailBox:delete(sid)
	local mail = self.mails[sid]
	if mail then
		self.mails[sid] = nil
	end
	return mail
end

-- 变更邮件状态
-- 1. 邮件编号
-- 2. 最新状态
function MailBox:change(sid, state)
	local mail = self.mails[sid]
	if mail then
		mail.state = state
	end
	return mail
end

---------------------------------------------------------------------
--- 直接数据操作
---------------------------------------------------------------------
local dbname = assert(skynet.getenv("database"))
local tbname = "mail"

-- 邮件数据操作集合
local db = 
{
	-- 新增邮件记录
	-- 1. 角色编号（角色编号为零表示系统邮件副本）
	-- 2. 邮件类型
	-- 3. 邮件来源
	-- 4. 邮件标题
	-- 5. 邮件正文
	-- 6. 附件信息
	-- 7. 创建时间
	-- 8. 到期时间
	insert = function(uid, category, from, title, content, attachments, timestamp, deadline)
		local sql = string.format("INSERT INTO %s(`uid`, `category`, `from`, `title`, `content`, `attachments`, `timestamp`, `deadline`, `state`) VALUES(%s, %s, %s, %s, %s, %s, %s, %s, %s)",
								   tbname,
								   uid,
								   category,
								   mysqlaux.quote_sql_str(skynet.packstring(from)),
								   mysqlaux.quote_sql_str(title),
								   mysqlaux.quote_sql_str(content),
								   mysqlaux.quote_sql_str(skynet.packstring(attachments)),
								   timestamp,
								   deadline,
								   ESTATUS.UNREAD)
		local ret = database.insert(dbname, sql)
		if not ret then
			return nil
		else
			return ret.insert_id
		end
	end,

	-- 更新邮件记录
	-- 1. 邮件编号
	-- 2. 邮件状态
	update = function(sid, state)
		local sql = string.format("UPDATE %s SET state = %s WHERE sid = %s", tbname, state, sid)
		return database.update(dbname, sql)
	end,

	-- 删除邮件记录
	-- 1. 邮件编号
	delete = function(sid)
		local sql = string.format("UPDATE %s SET removed = 1 WHERE sid = %s", tbname, sid)
		return database.update(dbname, sql)
	end,

	-- 查询角色邮件
	-- 1. 角色编号
	select = function(uid)
		-- 1. 不加载已删除邮件
		-- 2. 不加载已超时邮件
		local sql = string.format("SELECT * FROM %s WHERE uid = '%s' AND removed = 0 AND (deadline = 0 OR deadline > %s)",
								   tbname,
								   uid,
								   os.time())
		return database.select(dbname, sql)
	end,

	-- 查询角色最大邮件id
	-- 1. 角色编号
	select_maxid = function(uid)
		-- 1. 不加载已删除邮件
		-- 2. 不加载已超时邮件
		local sql = string.format("SELECT max(sid) as sid FROM %s WHERE uid = '%s'",
								   tbname,
								   uid)
		return database.select(dbname, sql)
	end,
}

---------------------------------------------------------------------
--- 内部变量/内部逻辑
---------------------------------------------------------------------
local madmin   = nil	-- 系统邮箱
local onlines  = {}		-- 在线邮箱

-- 邮件有效时长（默认7天）
local duration = 7 * 24 * 3600

-- 发送邮件（返回邮件编号）
-- 1. 角色编号
-- 2. 邮件类型
-- 3. 邮件来源
-- 4. 邮件标题
-- 5. 邮件正文
-- 6. 附件信息({{id, count}, ...})
-- 7. 创建时间
-- 8. 到期时间
local function deliver(uid, mail)
	-- 选择邮箱
	local mailbox = madmin
	if uid ~= "0" then
		mailbox = onlines[uid]
	end
	-- 插入邮件
	local sid = assert(db.insert(uid, mail.category, mail.from, mail.title, mail.content, mail.attachments, mail.timestamp, mail.deadline))
	if mailbox then
		mailbox:insert(sid, mail.category, mail.from, mail.title, mail.content, mail.attachments, mail.timestamp, mail.deadline, ESTATUS.UNREAD)
	end
	return tostring(sid)
end

-- 更新邮件（仅仅更新状态）
-- 1. 角色编号
-- 2. 邮件编号
-- 3. 邮件状态
local function change(uid, mid, state)
	local mailbox = assert(("0" == uid) and madmin or onlines[uid])
	db.update(mid, state)
	return mailbox:change(mid, state)
end

-- 删除邮件（仅仅设置标志）
-- 1. 角色编号
-- 2. 邮件编号
local function delete(uid, mid)
	local mailbox = assert(("0" == uid) and madmin or onlines[uid])
	db.delete(mid)
	return mailbox:delete(mid)
end

-- 邮件变动通知（使用旧有协议）
-- 1. 通知类型
-- 2. 角色编号
-- 2. 邮件内容
local function notice(mode, uid, mail)
	-- 按类型选择通知逻辑
	local operations = 
	{
		-- 新增邮件通知
		[ENOTICE.APPEND] = function()
			local name = "mail_event_notify"
			local data = 
			{
				operate  = MAIL_EVENT.NEW,
				sid      = mail.sid,
				category = mail.category,
			}
			skynet.send(GAME.SERVICE.ONLINED, "lua", "usersend", uid, "response", name, data)
		end,
		-- 删除邮件通知
		[ENOTICE.DELETE] = function()
			local name = "mail_event_notify"
			local data = 
			{
				operate  = MAIL_EVENT.DEL,
				sid      = mail.sid,
				category = mail.category,
			}
			skynet.send(GAME.SERVICE.ONLINED, "lua", "usersend", uid, "response", name, data)
		end,
	}
	-- 执行邮件变动通知
	if mail ~= nil then
		local fn = operations[mode]
		if fn then
			fn()
		end
	end
end

---------------------------------------------------------------------
--- 服务导出接口
---------------------------------------------------------------------
local COMMAND = {}

-- 服务启动通知
function COMMAND.setup()
	assert(madmin == nil, "mail : repeated initialization!!!")
	-- 加载系统邮件
	madmin = MailBox.new()
	for _, v in pairs(db.select(0) or {}) do
		madmin:insert(v.sid, v.category, skynet.unpack(v.from), v.title, v.content, skynet.unpack(v.attachments), v.timestamp, v.deadline, ESTATUS.UNREAD)
	end

	-- 群发邮件
	local function broadcast_mail(mail)
		local ret,data = skynet.call(GAME.SERVICE.ONLINED, "lua", "onlines")
		if ret == 0 then
			for _,uid in pairs(data) do
				local sid = deliver(uid, mail)
				mail.sid = sid
				notice(ENOTICE.APPEND, uid, mail)
			end
		end
	end

	-- 计算任务间隔(间隔单位 : 10ms)
	-- 1. 任务间距
	local function interval()
		return 60 * 100
	end

	-- 定时任务逻辑
	local function schedule()
		-- 邮件激活检查
		for k, v in pairs(madmin.mails) do
			repeat
				-- 移除无效系统邮件
				if (v.deadline < os.time()) and (v.deadline ~= 0) then
					madmin.mails[k] = nil
					break
				end
				-- 过滤不可激活邮件
				if (v.timestamp > os.time()) then
					break
				end
				-- 过滤已经激活邮件
				if (v.state ~= ESTATUS.UNREAD) then
					break
				end

				local cpMail = table.deep_clone(v,true)
				-- 群发邮件
				broadcast_mail(cpMail)

				change("0", k, ESTATUS.READ)
			until(true)
		end

		-- 重置定时任务
		skynet.timeout(interval(), schedule)
	end
	-- 启动定时任务
	skynet.timeout(interval(), schedule)
end

-- 服务停止通知
function COMMAND.on_exit()
end

-- 添加用户
function COMMAND.new_user(uid)
    -- 获取用户邮箱
	local mailbox = onlines[uid]
	if not mailbox then
		-- 构建邮箱
		mailbox = MailBox.new()
		for _, v in pairs(db.select(uid) or {}) do
			mailbox:insert(v.sid, v.category, skynet.unpack(v.from), v.title, v.content, skynet.unpack(v.attachments), v.timestamp, v.deadline, v.state)
		end

		onlines[uid] = mailbox
	end
end

-- 请求用户邮件（加载系统邮件）
-- 1. 角色编号
-- 2. 角色注册时间
function COMMAND.query(uid, register_time)
	-- 获取用户邮箱
	local mailbox = onlines[uid]
	if not mailbox then
		-- 构建邮箱
		mailbox = MailBox.new()
		for _, v in pairs(db.select(uid) or {}) do
			mailbox:insert(v.sid, v.category, skynet.unpack(v.from), v.title, v.content, skynet.unpack(v.attachments), v.timestamp, v.deadline, v.state)
		end

		onlines[uid] = mailbox
	end

	-- 计算最大邮件id
	local sid = 0
	local mid = mailbox.mid
	if mid == 0 then
		local selectobj = db.select_maxid(uid)
		for _, v in pairs(selectobj or {}) do
			if v.sid then
				mid = v.sid
				mailbox.mid = mid
			end
		end
	end

	-- 递送系统邮件
	local ctime = os.time()
	local mails = {}

	for _, v in pairs(madmin.mails) do
		repeat
			sid =  tonumber(v.sid)
			-- 过滤已加载系统邮件
			if (sid <= mid) then
				break
			end
			if (v.state ~= ESTATUS.READ) then
				break
			end
			-- 过滤未激活系统邮件
			if (v.timestamp > ctime) then
				break
			end
			-- 过滤已超时系统邮件
			if (v.deadline < ctime) and (v.deadline ~= 0) then
				break
			end
			-- 角色已经注册
			if (v.timestamp < register_time) then
				break
			end
			-- 记录可递送系统邮件
			table.insert(mails, v)
		until(true)
	end

	for _, v in pairs(mails) do
		-- 递送系统邮件
		v.timestamp = ctime
		v.deadline = ctime + duration
		local mid = deliver(uid, v)
		-- if mark ~= nil then
		-- 	notice(ENOTICE.APPEND, uid, mailbox.mails[mid])
		-- end
	end

	return mailbox.mails
end

-- 递送用户邮件（允许邮件群发）
-- 1. 角色编号
-- 2. 邮件信息
function COMMAND.deliver_mail(uids, mail)
	local ctime = os.time()
	for _, uid in pairs((type(uids) == "table") and uids or {uids}) do
		repeat
			-- 防止递送到系统邮箱
			if "0" == uid then
				break
			end
			-- 递送邮件并通知用户
			local mailbox = onlines[uid]
			mail.timestamp = ctime
			mail.deadline = ctime + duration
			local mid     = deliver(uid, mail)

			if mailbox ~= nil then
				notice(ENOTICE.APPEND, uid, mailbox.mails[mid])
			end
		until(true)
	end
	return 0
end

-- 删除用户邮件（允许批量删除）
-- 1. 角色编号
-- 2. 邮件编号
function COMMAND.delete(uid, mids)
	for _, mid in pairs((type(mids) == "table") and mids or {mids}) do
		local mail = delete(uid, mid)
		if mail ~= nil then
			notice(ENOTICE.DELETE, uid, mail)
		end
	end
	return 0
end

-- 更新邮件状态（标记为已读/已领）
-- 1. 角色编号
-- 2. 邮件编号
-- 3. 邮件状态
function COMMAND.change(uid, mid, state)
	-- 获取用户邮箱
	local mailbox = onlines[uid]
	if mailbox == nil then
		return ERRCODE.MAIL_COMMON_ERROR
	end
	-- 获取指定邮件
	local mail = mailbox.mails[mid]
	if mail == nil then
		return ERRCODE.MAIL_NOT_EXISTS
	end
	-- 更新邮件状态
	if table.empty(mail.attachments) or (state == ESTATUS.RECEIVED) then
		-- 删除邮件
		delete(uid, mid)
		notice(ENOTICE.DELETE, uid, mail)
	else
		-- 更新状态
		change(uid, mid, state)
	end
	return 0
end

-- 改变邮件状态
function COMMAND.update_state(uid, mail_states)
    for _, v in pairs(mail_states) do
        this.call("change", uid, v.sid, v.state)
    end
end

-- 根据sids加载邮件
-- @param uid - 角色id
-- @param sids - 读取sids列表
-- @return {*mail}
function COMMAND.load_mails(uid, category, sids)

	local mailbox = onlines[uid]
    if not mailbox then
        LOG_ERROR("uid[%s] mailbox is nil", uid)
        return
    end

    local kv_sids = {}
    for _, sid in pairs(sids) do
        kv_sids[sid] = 1
    end

    local mails = {}

    for _,v in pairs(mailbox.mails) do
        if kv_sids[v.sid] and v.category == category then
            table.insert(mails, v)
        end
    end

    return mails
end

-- 递送系统邮件（返回邮件编号）
-- 1. 邮件内容
function COMMAND.gm_deliver(mail)	
	return deliver("0", mail)
end

-- 删除系统邮件
-- 1. 邮件编号
function COMMAND.gm_delete(mid)
	return delete("0", mid)
end

---------------------------------------------------------------------
--- 注册邮件管理服务
---------------------------------------------------------------------
service.register({
	CMD = COMMAND,
})
