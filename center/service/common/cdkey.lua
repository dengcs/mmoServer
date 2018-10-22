---------------------------------------------------------------------
--- 简单礼包激活码服务（直接访问数据库）
---------------------------------------------------------------------
local service  = require "service"
local skynet   = require "skynet"
local database = require "common.database"
local md5      = require "md5"
local mysqlaux = require "skynet.mysqlaux.c"

---------------------------------------------------------------------
--- 内部变量/内部逻辑
---------------------------------------------------------------------

-- 礼包数据关联数据库
local dbname = assert(skynet.getenv("database") or skynet.getenv("db_name"))

-- 礼包数据关联数据表
local tbstorage = "cdkey_storage"
local tburecord = "cdkey_urecord"

-- 查询指定礼包信息
-- 1. 礼包序号
local function query(key)
	local sql = string.format("SELECT * FROM %s WHERE id = %s", tbstorage, mysqlaux.quote_sql_str(key))
	local ret = database.select(dbname, sql)
	if ret and ret[1] then
		ret = ret[1]
		ret.awards = skynet.unpack(ret.awards)
	end
	return ret
end

---------------------------------------------------------------------
--- 服务导出接口
---------------------------------------------------------------------
local COMMAND = {}

-- 批量生成礼包激活码（虽然概率极其微小，但是如果出现礼包序号冲突，默认放弃冲突礼包）
-- 1. 批次名称
-- 2. 批次描述
-- 3. 等级下限
-- 4. 等级上限
-- 5. 生效时间
-- 6. 失效时间
-- 7. 礼包信息
-- 8. 绑定角色
-- 9. 重复领取标记
-- 0. 礼包数量
function COMMAND.generate(name, summary, lvmin, lvmax, stime, etime, awards, bind, repeateable, count)
	-- 礼包记录入库操作（返回礼包序号）
	-- 1. 扩展信息
	local function insert(exdata)
		local key = md5.sumhexa(skynet.packstring({name, summary, lvmin, lvmax, stime, etime, awards, bind, repeateable, exdata, os.time()}))
		local sql = string.format("INSERT INTO %s(id, name, summary, lvmin, lvmax, stime, etime, awards, bind, repeateable) VALUES(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s);",
								   tbstorage,
								   mysqlaux.quote_sql_str(key    ),
								   mysqlaux.quote_sql_str(name   ),
								   mysqlaux.quote_sql_str(summary),
								   lvmin or 0,
								   lvmax or 0,
								   stime or 0,
								   etime or 0,
								   mysqlaux.quote_sql_str(skynet.packstring(awards)),
								   mysqlaux.quote_sql_str(bind or ""),
								   (repeateable ~= 0) and 0 or 1)
		-- 礼包记录入库
		local ret = database.insert(dbname, sql)
		if not ret then
			key = nil
			LOG_ERROR("'%s' execute failed!!!", sql)
		end
		return key
	end
	-- 礼包批量生成操作
	local retval = {}
	local random = math.random(os.time())
	for i = random, (random + math.max(0, count - 1)) do
		-- 防止礼包序号冲突（重复尝试3次）
		for _, m in pairs({101, 307, 401}) do
			local key = insert({i, m})
			if key ~= nil then
				table.insert(retval, key)
				break
			end
		end
	end
	return retval
end

-- 查询指定礼包信息
-- 1. 礼包序号
function COMMAND.query(key)
	local sql = string.format("SELECT * FROM '%s' WHERE id == %s", tbstorage, mysqlaux.quote_sql_str(key))
	local ret = database.select(dbname, sql)
	ret = ret and ret[1] or nil
	if ret ~= nil then
		ret.awards = skynet.unpack(ret.awards)
	end
	return ret
end

-- 删除指定礼包
-- 1. 删除模式（0 - 删除指定礼包， 1 - 删除指定批次）
-- 2. 操作键值
function COMMAND.delete(mode, key)
	if mode == 0 then
		local sql = string.format("DELETE FROM %s WHERE id = '%s'", tbstorage, key)
		return database.delete(dbname, sql)
	else
		local sql = string.format("DELETE FROM %s WHERE name = '%s'", tbstorage, key)
		return database.delete(dbname, sql)
	end
end

-- 激活锁定记录（防止激活重入）
local locked = {}

-- 激活指定礼包
-- 1. 礼包序号
-- 2. 角色编号
-- 3. 角色等级
function COMMAND.active(key, uid, level)
	-- 查询指定角色指定批次礼包领取次数
	-- 1. 批次名称
	-- 2. 角色编号
	local function uquery(name, uid)
		-- 构建查询语句
		local sql = string.format("SELECT count FROM %s WHERE name = %s AND uid = %s",
								   tburecord,
								   mysqlaux.quote_sql_str(name),
								   mysqlaux.quote_sql_str(uid))
		-- 查询领取次数
		local ret = database.select(dbname, sql)
		ret = ret and ret[1]
		if ret then
			return ret.count
		else
			return 0
		end
	end
	-- 更新指定角色指定批次礼包领取次数
	-- 1. 批次名称
	-- 2. 角色编号
	local function update(name, uid)
		-- 构建更新语句（存在则自动加一）
		local sql = string.format("INSERT INTO %s(name, uid, count) VALUES(%s, %s, 1) ON DUPLICATE KEY UPDATE count = count + 1;",
								   tburecord,
								   mysqlaux.quote_sql_str(name),
								   mysqlaux.quote_sql_str(uid))
		-- 更新领取次数
		database.select(dbname, sql)
	end
	-- 激活指定礼包（设置为已领取）
	-- 1. 礼包序号
	-- 2. 角色编号
	local function active(key, uid)
		local sql = string.format("UPDATE %s SET received = 1 WHERE id = %s", tbstorage, mysqlaux.quote_sql_str(key))
		database.update(dbname, sql)
	end
	-- 锁定激活操作
	if not locked[key] then
		locked[key] = 1
	else
		return { ERRCODE.CDKEY_REENTRANT_FAILED }
	end
	-- 礼包领取过程
	local errcode = 0
	local awards  = nil
	repeat
		-- 查询礼包信息
		local v = query(key)
		if not v then
			errcode = ERRCODE.CDKEY_NOT_EXISTS
			break
		end
		-- 礼包激活判断
		if v.received ~= 0 then
			errcode = ERRCODE.CDKEY_ALREADY_RECEIVED
			break
		end
		-- 礼包期限判断
		local ctime = os.time()
		if (v.stime ~= 0 and v.stime > ctime) or (v.etime ~= 0 and v.etime < ctime) then
			errcode = ERRCODE.CDKEY_ALREADY_EXPIRED
			break
		end
		-- 角色等级判断
		if (v.lvmin ~= 0 and v.lvmin > level) or (v.lvmax ~= 0 and v.lvmax < level) then
			errcode = ERRCODE.CDKEY_LEVEL_LIMIT
			break
		end
		-- 绑定条件判断
		if v.bind ~= nil and v.bind ~= "" then
			local available = false
			for _, m in pairs(v.bind:split2(",")) do
				if m == uid then
					available = true
					break
				end
			end
			if not available then
				errcode = ERRCODE.CDKEY_PERMISSION_DINIED
				break
			end
		end
		-- 重复领取判断
		if v.repeateable == 0 then
			if uquery(v.name, uid) ~= 0 then
 				errcode = ERRCODE.CDKEY_ALREADY_RECEIVED
 				break
 			end
 		end
 		-- 允许领取礼包
 		active(key   , uid)
 		update(v.name, uid)
 		awards = v.awards
 	until(true)
	-- 解除锁定并返回
	locked[key] = nil
	return { errcode, awards }
end

---------------------------------------------------------------------
--- 注册礼包激活码服务
---------------------------------------------------------------------
local handler = {}

-- 消息分发逻辑
-- 1. 消息来源
-- 2. 消息类型
-- 3. 消息内容
function handler.command_handler(source, cmd, ...)
	local fn = COMMAND[cmd]
	if fn then
		return fn(source, ...)
	else
		ERROR("svcmanager : command[%s] can't find!!!", cmd)
	end
end

service.start(handler)
