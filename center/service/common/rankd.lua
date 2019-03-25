---------------------------------------------------------------------
--- 排行榜服务
---------------------------------------------------------------------
local service  = require "factory.service"
local database = require "common.database"

---------------------------------------------------------------------
--- 榜单模型
---------------------------------------------------------------------
local Board = class("board")

-- 构建榜单对象(默认降序排列)
-- 1. 仓库名称
-- 2. 榜单别名
-- 3. 升序标记
function Board:ctor(dbase, alias, ascending)
	self.dbase      = assert(dbase)
	self.alias      = assert(alias)
	self.descending = (ascending == nil)
end

-- 更新目标排名
-- 1. 目标键值
-- 2. 目标积分
function Board:update(key, score)
	-- 更新角色排名
	local ctime = this.time()
	local value = nil
	if not self.descending then
		-- 降序模式
		value = (score << 32) + (0xFFFFFFFF - ctime)
	else
		-- 升序模式
		value = (score << 32) + ctime
	end
	local retval = (database.exec(self.dbase, "zadd", self.alias, value, key) or {}).retval
	if retval ~= nil then
		return true
	else
		return false
	end
end

-- 获取目标排名
-- 1. 目标键值
function Board:rank(key)
	local retval = nil
	if self.descending then
		-- 降序模式
		retval = (database.exec(self.dbase, "zrevrank", self.alias, key) or {}).retval
	else
		-- 升序模式
		retval = (database.exec(self.dbase, "zrank",    self.alias, key) or {}).retval
	end
	if retval ~= nil then
		return retval + 1
	else
		return nil
	end
end

-- 获取目标积分
-- 1. 目标键值
function Board:score(key)
	local retval = (database.exec(self.dbase, "zscore", self.alias, key) or {}).retval
	if retval then
		retval = (retval >> 32)
	end
	return retval
end

-- 查询分数区间的榜单信息(闭区间)
-- 1. 查询分数起点
-- 2. 查询分数终点
function Board:range_byscore(sscore, escore, offset, count)
	sscore = math.max(0     ,sscore)
	escore = math.max(0     ,escore)
	-- offset = offset
	-- count = count
	local ctime = this.time()
	if not self.descending then
		-- 降序模式
		sscore = (sscore << 32) + (0xFFFFFFFF - ctime)
		escore = (escore << 32) + (0xFFFFFFFF - ctime)
	else
		-- 升序模式
		sscore = (sscore << 32) + ctime
		escore = (escore << 32) + ctime
	end
	local retval = nil
	if self.descending then
		-- 降序模式
		if not offset or not count then
			retval = (database.exec(self.dbase, "zrevrangebyscore", self.alias, escore, sscore,"WITHSCORES") or {}).retval
		else
			retval = (database.exec(self.dbase, "zrevrangebyscore", self.alias, escore, sscore,"WITHSCORES","limit",offset,count) or {}).retval
		end
	else
		-- 升序模式
		if not offset or not count then
			retval = (database.exec(self.dbase, "zrangebyscore", self.alias, sscore, escore,"WITHSCORES") or {}).retval
		else
			retval = (database.exec(self.dbase, "zrangebyscore", self.alias, sscore, escore,"WITHSCORES","limit",offset,count) or {}).retval
		end
	end
	local result = {}
	for i = 1, #retval, 2 do
		local key   = retval[i + 0]
		local score = retval[i + 1] >> 32
		table.insert(result, {key = key, score = score})
	end
	return result
end

-- 查询榜单信息
-- 1. 查询起点
-- 2. 查询终点
function Board:range_byrank(spoint, epoint)
	spoint = math.max(0     , spoint)
	epoint = math.max(epoint, spoint)
	local retval = nil
	if self.descending then
		-- 降序模式
		retval = (database.exec(self.dbase, "zrevrange", self.alias, spoint, epoint) or {}).retval
	else
		-- 升序模式
		retval = (database.exec(self.dbase, "zrange",    self.alias, spoint, epoint) or {}).retval
	end
	return retval
end

-- 查询榜单信息
-- 1. 查询起点
-- 2. 查询终点
function Board:range(spoint, epoint)
	local spoint = math.max(0     , spoint)
	local epoint = math.max(epoint, spoint)
	local result = {}
	local retval = nil
	if self.descending then
		-- 降序模式
		retval = (database.exec(self.dbase, "zrevrange", self.alias, spoint, epoint, "WITHSCORES") or {}).retval
	else
		-- 升序模式
		retval = (database.exec(self.dbase, "zrange",    self.alias, spoint, epoint, "WITHSCORES") or {}).retval
	end
	if retval ~= nil then
		for i = 1, #retval, 2 do
			local pos   = spoint + math.floor((i + 1) / 2)
			local key   = retval[i + 0]
			local score = retval[i + 1] >> 32
			table.insert(result, { pos = pos, key = key, score = score })
		end
	end
	return result
end

-- 删除目标排名
-- 1. 目标键值
function Board:remove(key)
	local retval = (database.exec(self.dbase, "zrem", self.alias, key) or {}).retval
	if retval ~= nil then
		return true
	else
		return false
	end
end

-- 清空当前榜单
function Board:cleanup()
	local retval = (database.exec(self.dbase, "zremrangebyrank", self.alias, 0, -1) or {}).retval
	if retval ~= nil then
		return true
	else
		return false
	end
end

---------------------------------------------------------------------
--- 内部变量/内部逻辑
---------------------------------------------------------------------

-- 榜单列表
local boards = {}

---------------------------------------------------------------------
--- 服务业务接口
---------------------------------------------------------------------
local command = {}

-- 更新目标排名(返回最新排名)
-- 1. 榜单别名
-- 2. 目标键值
-- 3. 目标积分
function command.update(alias, key, score)
	local board = boards[alias]
	if board ~= nil then
		board:update(key, assert(tonumber(score)))
	end
end

-- 获取目标排名
-- 1. 榜单别名
-- 2. 目标键值
function command.rank(alias, key)
	local board = boards[alias]
	if board ~= nil then
		return board:rank(key)
	else
		return nil
	end
end

-- 获取目标积分
-- 1. 榜单别名
-- 2. 目标键值
function command.score(alias, key)
	local board = boards[alias]
	if board ~= nil then
		return board:score(key)
	else
		return nil
	end
end

-- 查询分数区间的榜单信息(闭区间)
-- 1. 查询分数起点
-- 2. 查询分数终点
function command.range_byscore(alias, sscore, escore, offset, count)
	local board = boards[alias]
	if board ~= nil then
		return board:range_byscore(sscore, escore, offset, count)
	else
		return nil
	end
end

-- 查询榜单信息
-- 1. 查询起点
-- 2. 查询终点
function command.range_byrank(alias, spoint, epoint)
	local board = boards[alias]
	if board ~= nil then
		return board:range_byrank(spoint, epoint)
	else
		return nil
	end
end

-- 查询榜单信息({ key : 目标键值, pos : 目标排名 , score : 目标积分 })
-- 1. 榜单别名
-- 2. 查询起点
-- 3. 查询终点
function command.range(alias, spoint, epoint)
	local board = boards[alias]
	if board ~= nil then
		return board:range(spoint, epoint)
	else
		return nil
	end
end

-- 删除指定目标
-- 1. 榜单别名
-- 2. 目标键值
function command.remove(alias, key)
	local board = boards[alias]
	if board ~= nil then
		return board:remmove(key)
	else
		return false
	end
end

-- 清空指定榜单
-- 1. 榜单别名
function command.cleanup(alias)
	local board = boards[alias]
	if board ~= nil then
		return board:cleanup()
	else
		return false
	end
end

---------------------------------------------------------------------
--- 服务回调接口
---------------------------------------------------------------------
local server = {}

-- 服务构造通知
-- 1. 构造配置
function server.on_init(config)
	-- 按配置构造榜单列表
	for _, v in pairs(config.boards or {}) do
		boards[v.alias] = Board.new(v.dbase, string.format("Board:%s", v.alias), v.ascending)
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
		ERROR("rank : command[%s] not found!!!", cmd)
	end
end

-- 启动排行榜服务
service.start(server)
