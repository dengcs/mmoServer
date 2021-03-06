local skynet    = require "skynet"
local service   = require "factory.service"
local db_social	= require "db.mongo.social"

-----------------------------------------------------------
--- 内部变量/内部逻辑
-----------------------------------------------------------

local function rank_monitor(alias, pid, value)
	local needUpdate = false

	if alias == "level" then
		needUpdate = true
	end

	if needUpdate then
		skynet.send(GLOBAL.SERVICE_NAME.RANK, "lua", "update", alias, pid, value)
	end
end

-----------------------------------------------------------
--- 内部類
-----------------------------------------------------------

-- 社交数据模型
local social = {}

function social:init()
    self.cache      	= {}
	self.cache_count  	= 0
    self.cache_max  	= 1000
end

function social:load(pid)
	local vData = db_social.get(pid)
	if vData then
		self.cache[pid] = vData
		return vData
	end
end

function social:update(pid, data)
	local vData = self.cache[pid] or self:load(pid)
	if not vData then
		vData = {dirty = false}
		self.cache[pid] = vData
		self.cache_count = self.cache_count + 1
	end

	for k,v in pairs(data or {}) do
		if v ~= vData[k] then
			vData[k] = v
			vData.dirty = true
			rank_monitor(k, pid, v)
		end
	end
end

function social:save(pid, clean)
	local vData = self.cache[pid]
	if vData then
		if vData.dirty then
			vData.dirty = false
			-- 保存数据
			db_social.set(pid, vData)
		end

		if clean then
			if self.cache_count > self.cache_max then
				self.cache[pid] = nil
				self.cache_count = self.cache_count - 1
			end
		end
	end
end

function social:save_all()
	for pid in pairs(self.cache) do
		self:save(pid)
	end
end

function social:get(pid)
	return self.cache[pid]
end

-----------------------------------------------------------
--- 服务业务接口
-----------------------------------------------------------

local CMD = {}

-- 加载数据
function CMD.load(pid)
	social:load(pid)
end

-- 同步数据
function CMD.update(pid, data)
	social:update(pid, data)
end

-- 保存数据
function CMD.save(pid)
	social:save(pid, true)
end

-- 获取指定用户数据
function CMD.get_user_data(pid)
	return social:get(pid)
end

function CMD.search_pid_by_name(name)
end

-- 搜索玩家
function CMD.search_friend(name)
end

-----------------------------------------------------------
--- 服务框架接口
-----------------------------------------------------------

-- 服务注册
local server = {}

-- 服务开启通知
-- 1. 构造参数
function server.init_handler(arguments)
	social:init()

	local function save_all()
		social:save_all()
	end
	this.schedule(save_all, 3600, SCHEDULER_FOREVER)
end

-- 服务退出通知
function server.exit_handler()
	social:save_all()
end

-- 消息分发逻辑
-- 1. 消息来源
-- 2. 消息类型
-- 3. 消息内容
function server.command_handler(source, cmd, ...)
	local fn = CMD[cmd]
	if fn then
		return fn(...)
	else
		LOG_ERROR("social : command[%s] can't find!!!", cmd)
	end
end

service.start(server)