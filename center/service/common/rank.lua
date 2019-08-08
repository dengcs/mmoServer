---------------------------------------------------------------------
--- 排行榜服务
---------------------------------------------------------------------
local service  	= require "factory.service"
local conf_rank	= require "config.rank"

tb_insert 	= table.insert
tb_remove 	= table.remove
tb_sort		= table.sort


---------------------------------------------------------------------
--- 内部变量/内部逻辑
---------------------------------------------------------------------

-- 榜单列表
local boards = {}

local function rank_comp(a, b)
	return a.value > b.value
end


---------------------------------------------------------------------
--- 榜单模型
---------------------------------------------------------------------
local Board = class("board")

-- 构建榜单对象(默认降序排列)
-- 1. 仓库名称
-- 2. 榜单别名
-- 3. 升序标记
function Board:ctor(alias, limit)
	self.alias     	= alias
	self.limit		= limit
	self.ranks		= {}
end

-- 更新目标排名
-- 1. 目标键值
-- 2. 目标积分
function Board:update(pid, value)
	local rank = nil
	for _,v in pairs(self.ranks) do
		if v.pid == pid then
			rank = v
			break
		end
	end

	if rank then
		rank.value = value
	else
		tb_insert(self.ranks, {pid = pid, value = value})
	end

	tb_sort(self.ranks, rank_comp)

	if #self.ranks > self.limit then
		tb_remove(self.ranks)
	end
end

-- 获取目标排名
-- 1. 目标键值
function Board:rank(pid)
	for _,rank in pairs(self.ranks) do
		if rank.pid == pid then
			return rank
		end
	end
end

-- 查询榜单信息
-- 1. 查询起点
-- 2. 查询终点
function Board:range_byrank(spoint, epoint)
	local ranks = {}
	for point,rank in pairs(self.ranks) do
		if point >= spoint and point <= epoint then
			tb_insert(ranks, rank)
		end
	end
	return ranks
end

-- 删除目标排名
-- 1. 目标键值
function Board:remove(pid)
	for k,rank in pairs(self.ranks) do
		if rank.pid == pid then
			tb_remove(self.ranks, k)
			break
		end
	end
end

-- 清空当前榜单
function Board:cleanup()
	self.ranks = {}
	self.limit = 0
end

---------------------------------------------------------------------
--- 服务业务接口
---------------------------------------------------------------------
local command = {}

-- 更新目标排名(返回最新排名)
-- 1. 榜单别名
-- 2. 目标键值
-- 3. 目标积分
function command.update(alias, pid, value)
	local board = boards[alias]
	if board then
		board:update(pid, tonumber(value))
	end
end

-- 获取目标排名
-- 1. 榜单别名
-- 2. 目标键值
function command.rank(alias, pid)
	local board = boards[alias]
	if board then
		return board:rank(pid)
	else
		return nil
	end
end

-- 查询榜单信息
-- 1. 查询起点
-- 2. 查询终点
function command.range_byrank(alias, spoint, epoint)
	local board = boards[alias]
	if board then
		return board:range_byrank(spoint, epoint)
	else
		return nil
	end
end

-- 删除指定目标
-- 1. 榜单别名
-- 2. 目标键值
function command.remove(alias, pid)
	local board = boards[alias]
	if board then
		return board:remove(pid)
	else
		return false
	end
end

-- 清空指定榜单
-- 1. 榜单别名
function command.cleanup(alias)
	local board = boards[alias]
	if board then
		return board:cleanup()
	else
		return false
	end
end

---------------------------------------------------------------------
--- 服务回调接口
---------------------------------------------------------------------
local server = {}

-- 服务开启通知
-- 1. 构造参数
function server.init_handler()
	for alias,limit in pairs(conf_rank) do
		boards[alias] = Board.new(alias, limit)
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
		ERROR("social : command[%s] not found!!!", cmd)
	end
end

-- 启动服务
service.start(server)
