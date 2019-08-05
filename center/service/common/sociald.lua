local skynet    = require "skynet"
local service   = require "factory.service"
local db_social	= require "db.mongo.social"

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
	local cdata = db_social.get(pid)
	if cdata then
		self.cache[pid] = cdata
	end
end

function social:update(pid, data)
	local cdata = self.cache[pid]
	if not cdata then
		cdata = {dirty = false}
		self.cache[pid] = cdata
		self.cache_count = self.cache_count + 1
	end

	for k,v in pairs(data or {}) do
		if v ~= cdata[k] then
			cdata[k] = v
			cdata.dirty = true
		end
	end
end

function social:save(pid, clean)
	local cdata = self.cache[pid]
	if cdata then
		if cdata.dirty then
			cdata.dirty = nil
			-- 保存数据
			db_social.set(pid, cdata)
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
		ERROR("social : command[%s] can't find!!!", cmd)
	end
end

service.start(server)