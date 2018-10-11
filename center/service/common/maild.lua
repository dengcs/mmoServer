---------------------------------------------------------------------
--- 邮件服务
---------------------------------------------------------------------
local skynet  = require "skynet"
local service = require "service"
local json    = require "cjson"
local database = require "common.database"
local mysqlaux = require "skynet.mysqlaux.c"

local onlines  = {}		-- 在线邮箱

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
	NEW   	 = 1,		-- 新增邮件
	DELETE   = 2,		-- 删除邮件
	UPDATE   = 3,		-- 邮件更新
}

-- gm邮件
local gm_mailbox = nil
---------------------------------------------------------------------
--- 数据对象
---------------------------------------------------------------------

local MailBox = {}
MailBox.__index = MailBox

-- 构建邮箱
-- 1. 角色编号
-- 2. 邮件标记
function MailBox.new()
	local mailbox = 
	{
		mid = 0, -- 最大邮件id
		mails = {},
		reg_time = 0, -- 玩家注册时间
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
function MailBox:insert(sid, category, from, title, content, attachments, timestamp, deadline, state, gm)
	-- 记录最大邮件ID
	if gm == 1 and sid > self.mid then
		self.mid = sid
	end

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
		gm 			= gm,
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
--- 数据库操作
---------------------------------------------------------------------
local dbname = "db.mysql"
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
	insert = function(pid, category, from, title, content, attachments, timestamp, deadline, gm)
		local sql = string.format("INSERT INTO %s(`pid`, `category`, `from`, `title`, `content`, `attachments`, `timestamp`, `deadline`, `state`, `gm`) VALUES(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
								   tbname,
								   pid,
								   category,
								   mysqlaux.quote_sql_str(json.encode(from)),
								   mysqlaux.quote_sql_str(title),
								   mysqlaux.quote_sql_str(content),
								   mysqlaux.quote_sql_str(json.encode(attachments)),
								   timestamp,
								   deadline,
								   ESTATUS.UNREAD,
								   gm)
		local ret = database.set(dbname, sql)
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
		return database.exec(dbname, sql)
	end,

	-- 删除邮件记录
	-- 1. 邮件编号
	delete = function(sid)
		local sql = string.format("UPDATE %s SET removed = 1 WHERE sid = %s", tbname, sid)
		return database.del(dbname, sql)
	end,

	-- 查询角色邮件
	-- 1. 角色编号
	select = function(pid)
		-- 1. 不加载已删除邮件
		-- 2. 不加载已超时邮件
		local sql = string.format("SELECT * FROM %s WHERE pid = %s AND removed = 0 AND (deadline = 0 OR deadline > %s)",
								   tbname,
								   pid,
								   this.time())
		return database.get(dbname, sql)
	end,
}

---------------------------------------------------------------------
--- 内部逻辑
---------------------------------------------------------------------

local function insert(pid, mail, gm)
    -- 选择邮箱
    local mailbox = onlines[pid]
	-- 插入邮件
	local sid = assert(db.insert(pid, mail.category, mail.from, mail.title, mail.content, mail.attachments, mail.timestamp, mail.deadline, gm))
	if mailbox then
		mailbox:insert(sid, mail.category, mail.from, mail.title, mail.content, mail.attachments, mail.timestamp, mail.deadline, ESTATUS.UNREAD, gm)
	end
	return sid
end

local function delete(pid, sid)
    local mailbox = assert(onlines[pid])
	db.delete(sid)
	return mailbox:delete(sid)
end

local function change(pid, sid, state)
    local mailbox = assert(onlines[pid])
	db.update(sid, state)
	return mailbox:change(sid, state)
end

-- 邮件变动通知（使用旧有协议）
-- 1. 通知类型
-- 2. 角色编号
-- 2. 邮件内容
local function notice(type, pid, mail)
	-- 按类型选择通知逻辑
	local operations = 
	{
		-- 新增邮件通知
		[ENOTICE.NEW] = function()
			local name = "mail_event_notify"
			local data = 
			{
				operate  = ENOTICE.NEW,
				sid      = mail.sid,
            }
            this.usersend(pid, "response_message", name, data)
		end,
		-- 删除邮件通知
		[ENOTICE.DELETE] = function()
			local name = "mail_event_notify"
			local data = 
			{
				operate  = ENOTICE.DELETE,
				sid      = mail.sid,
			}
			this.usersend(pid, "response_message", name, data)
		end,
	}
	-- 执行邮件变动通知
	if mail ~= nil then
		local fn = operations[type]
		if fn then
			fn()
		end
	end
end

local function schedule()
	-- 逻辑
	local function fn()
		-- 删除过期邮件
		local now = this.time()
		for pid,mailbox in pairs(onlines) do
			for _,mail in pairs(mailbox.mails or {}) do
				-- 删除已超时系统邮件
				if (mail.deadline < now) and (mail.deadline ~= 0) then
					delete(pid, mail.sid)
					if pid ~= 0 then
						notice(ENOTICE.DELETE, pid, mail)
					end
				end
			end
		end

		-- 递送系统邮件
		if gm_mailbox then
			for _,gm_mail in pairs(gm_mailbox.mails or {}) do
				for pid,mailbox in pairs(onlines) do
					local mid = mailbox.mid

					repeat
						if pid == 0 then
							break
						end
						-- 过滤已加载系统邮件
						if (gm_mail.sid <= mid) then
							break
						end
						-- 过滤未激活系统邮件
						if (gm_mail.timestamp > now) then
							break
						end
						-- 角色已经注册
						if (gm_mail.timestamp < mailbox.reg_time) then
							break
						end

						-- 递送系统邮件
						local mail = table.deepclone(gm_mail, true)
						local duration = mail.deadline - mail.timestamp
						mail.timestamp = now
						mail.deadline = now + duration
						local sid = insert(pid, mail, 1)
						mail.sid = sid
        				notice(ENOTICE.NEW, pid, mail)
					until(true)
				end
			end
		end
	end
	
    -- 异常处理
    local function catch(message)
        LOG_ERROR(message)
	end
	
	-- 间隔时间
	local function interval()	
		return 300
	end
    
    -- 任务处理
	xpcall(fn, catch)
	skynet.timeout(interval(), schedule)
end

---------------------------------------------------------------------
--- 服务业务接口
---------------------------------------------------------------------
local command = {}

-- 新增条目
function command.new(pid)
    local mailbox = onlines[pid]
    if not mailbox then
        mailbox = MailBox.new()
        onlines[pid] = mailbox
    end
end

-- 删除条目
function command.drop(pid)
    onlines[pid] = nil
end

-- 发邮件
function command.send(pid, mail)
	assert(mail)
    local pids = IS_TABLE(pid) and pid or {pid}
    for _,id in pairs(pids) do
		local sid = insert(id, mail, 0)
		mail.sid = sid
        notice(ENOTICE.NEW, id, mail)
    end
end

-- 加载邮件
function command.load(pid, reg_time)
    local mailbox = onlines[pid]
    if not mailbox then
        mailbox = MailBox.new()
        onlines[pid] = mailbox

        local dbdata = db.select(pid)
		for _,v in pairs(dbdata or {}) do
			local attachments = (v.attachments and v.attachments ~= "null") and json.decode(v.attachments) or nil
			mailbox:insert(v.sid, v.category, json.decode(v.from), v.title, v.content, attachments, v.timestamp, v.deadline, v.state, v.gm)
        end
	end

	mailbox.reg_time = reg_time
	
	local mid = mailbox.mid
	-- 递送系统邮件
	local now = this.time()
	local mails = {}

	for _, v in pairs(gm_mailbox.mails) do
		repeat
			-- 过滤已加载系统邮件
			if (v.sid <= mid) then
				break
			end
			-- 过滤未激活系统邮件
			if (v.timestamp > now) then
				break
			end
			-- 过滤已超时系统邮件
			if (v.deadline < now) and (v.deadline ~= 0) then
				break
			end
			-- 角色已经注册
			if (v.timestamp < reg_time) then
				break
			end
			-- 记录可递送系统邮件
			table.insert(mails, v)
		until(true)
	end

	for _, v in pairs(mails) do
		-- 递送系统邮件
		local duration = v.deadline - v.timestamp
		v.timestamp = now
		v.deadline = now + duration
		insert(pid, v, 1)
	end
	
	local loadmails = table.deepclone(mailbox.mails, true)
	print("dcs---"..table.tostring(loadmails))

	return loadmails
end

-- 获取固定邮件
function command.get(pid, sid)
	local mails = {}

	local mailbox = onlines[pid]
	if mailbox then
		local sids = IS_TABLE(sid) and sid or {sid}
		for _,id in pairs(sids) do
			for _,v in pairs(mailbox.mails) do
				if id == v.sid then
					local mail = table.deepclone(v, true)
					table.insert(mails, mail)
					break
				end
			end
		end
	end
	
	return mails
end

-- 删除邮件
function command.del(pid, sid)
    local sids = IS_TABLE(sid) and sid or {sid}
    for _,id in pairs(sids) do
        local mail = delete(pid, id)
        notice(ENOTICE.DELETE, pid, mail)
    end
end

-- 更新状态
function command.change(pid, sid, state)
    local sids = IS_TABLE(sid) and sid or {sid}
    for _,id in pairs(sids) do
        change(pid, id, state)
        this.usersend(pid, "response_message", "mail_state_notify", {sid = id, state = state})
    end
end

-- 发全体邮件
function command.gm_send(mail)
	assert(mail)
	insert(0, mail, 1)
end

function command.gm_del(sid)
	delete(0, sid)
end

---------------------------------------------------------------------
--- 服务回调接口
---------------------------------------------------------------------
local server = {}

function server.on_init(config)
	gm_mailbox = MailBox.new()
	onlines[0] = gm_mailbox

	local dbdata = db.select(0)
	for _,v in pairs(dbdata or {}) do
		local attachments = (v.attachments and v.attachments ~= "null") and json.decode(v.attachments) or nil
		gm_mailbox:insert(v.sid, v.category, json.decode(v.from), v.title, v.content, attachments, v.timestamp, v.deadline, v.state)
	end

	schedule()
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
        return dispatcher:command_dispatch({}, cmd, ...)
    end
end

-- 启动网关服务
service.simple.start(server)