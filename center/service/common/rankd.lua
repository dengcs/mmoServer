--
-- 附带数据的排行榜服务
--
local service = require "service"
local skynet  = require "skynet"
local nova    = require "nova"
local timer   = require "utils.timer"
local random  = require "utils.random"

local COMMAND = {}

-------------------------------------------------
--- 排行榜模型
-------------------------------------------------
local Rank = {}
Rank.__index = Rank

-- 排序类型枚举
local RANK_ORDER_TYPE =
{
	ASCENDING  = 1,		-- 升序
	DESCENDING = 2,		-- 降序
}

-- 构造排行榜对象
function Rank.new(alias, order, uplimit, is_not_user)
	local rank = {}
	-- 注册成员方法
	for k, v in pairs(Rank) do
		rank[k] = v
	end
	-- 初始化排行榜
	rank.alias   = alias									-- 排行榜别名
	rank.count   = 0										-- 排行榜当前上榜数量
	rank.dirty   = false									-- 排行榜变更标记
	rank.order   = order   or RANK_ORDER_TYPE.DESCENDING	-- 排行榜排序类型（默认降序排列）
	rank.uplimit = uplimit or 300							-- 排行榜人数上限
	rank.ranking = {}										-- 排行信息
	rank.members = {}										-- 成员信息
	rank.is_not_user = is_not_user or false
	return rank
end

-- 保存排行榜
function Rank:save()
	if self.dirty then
		nova.send(GAME.SERVICE.KVCACHED, "lua", "set", string.format("kvcached.rank.%s", self.alias), self.ranking)
		self.dirty = false
	end
end

-- 加载排行榜
function Rank:load()
	-- 读取排行榜信息
	local _, ranking = nova.call(GAME.SERVICE.KVCACHED, "lua", "get", string.format("kvcached.rank.%s", self.alias))
	if ranking ~= nil then
		for _, v in pairs(ranking) do
			self:update(v.uid, v.score, v.param)
			self.dirty = false
		end
	end
end

-- 更新排行榜数据(需考虑排位下降的情况)
function Rank:update(uid, score, param)
	-- 更新排位记录
	local direct = 1
	local idx    = self.members[uid]
	if idx == nil then
		idx = self.count + 1
		self.count = idx
	else
		local m = self.ranking[idx]
		if self.order == RANK_ORDER_TYPE.ASCENDING  and (score > m.score) then
			direct = -1
		end
		if self.order == RANK_ORDER_TYPE.DESCENDING and (score < m.score) then
			direct = -1
		end
		-- 处理排位参数
		if param == nil then
			param = m.param
		end
	end
	self.members[uid] = idx
	self.ranking[idx] = {uid = uid, score = score, param = param}
	-- 排位更新
	while true do
		local v1 = idx
		local v2 = idx - direct
		local m1 = self.ranking[v1]
		local m2 = self.ranking[v2]
		if m1 == nil or m2 == nil then
			break
		end
		if v1 > v2 then
			if self.order == RANK_ORDER_TYPE.ASCENDING  and (m1.score >= m2.score) then
				break
			end
			if self.order == RANK_ORDER_TYPE.DESCENDING and (m1.score <= m2.score) then
				break
			end
		else
			if self.order == RANK_ORDER_TYPE.ASCENDING  and (m1.score <= m2.score) then
				break
			end
			if self.order == RANK_ORDER_TYPE.DESCENDING and (m1.score >= m2.score) then
				break
			end
		end
		self.ranking[v2    ] = m1
		self.ranking[v1    ] = m2
		self.members[m1.uid] = v2
		self.members[m2.uid] = v1
		-- 移动排位
		idx = v2
	end
	-- 整理排行榜
	while self.count > self.uplimit do
		local idx = self.count
		local uid = self.ranking[idx].uid
		self.ranking[idx] = nil
		self.members[uid] = nil
		self.count = self.count - 1
	end
	-- 设置脏标记并返回最新排行
	local idx = self.members[uid]
	if idx ~= nil then
		self.dirty = true
	end
	return idx
end

-- 获取指定角色排名
function Rank:revrank(uid)
	return self.members[uid]
end

-- 获取指定角色排名加分数
function Rank:revrank_withscore(uid)
    if self.members[uid] then
        local rank_id = self.members[uid]
        return {rank_id = rank_id, score = self.ranking[rank_id].score}
    else
        return {rank_id = 0, score = 0}
    end
end

-- 获取指定区间内排名信息
function Rank:revrange(spoint, epoint)
	spoint = math.max(spoint, 1)
	epoint = math.max(spoint, epoint)
	local retval = {}
	for i = spoint, epoint do
		local m = self.ranking[i]
		if m ~= nil then
			retval[i] = m
		else
			break
		end
	end
	return retval
end

-- 检索符合条件的uid列表
-- @ param uid 用户id
-- @ param filter 过滤列表
-- @ param onlines 在线列表
-- @ param max_num 需要的数量
function Rank:select_condition_uids(uid, filter_list, onlines_list, max_num)
	local add_num = 0
    local ret = {}

    if onlines_list then
    	table.insert(onlines_list, uid)
    end

    -- 获取在线排行榜靠前玩家
    for k,v in ipairs(self.ranking or {}) do
    	local t_uid = self.ranking[k].uid
    	if add_num < max_num then
	    	if table.contains(onlines_list,t_uid) and filter_list[t_uid] == nil then    		
	            table.insert(ret, t_uid)
	            add_num = add_num + 1
	        end
    	end
    end

    -- 获取离线线排行榜靠前玩家
    if add_num < max_num then
	    for k,v in ipairs(self.ranking or {}) do
	    	local t_uid = self.ranking[k].uid
	    	if add_num < max_num then
		    	if table.contains(onlines_list,t_uid) == false and filter_list[t_uid] == nil then    		
		            table.insert(ret, t_uid)
		            add_num = add_num + 1
		        end
	    	end
	    end
    end

    return ret
end

-------------------------------------------------
--- 内部参数/内部逻辑
-------------------------------------------------

-- 排行榜列表
local ranks = {}

-- 定时器间隔(秒)
local interval = 600

-- 定时任务
local function on_timer()
	-- 具体定时任务
	local function fn()
		for _, v in pairs(ranks) do
			v:save()
		end
	end
	-- 安全执行定时器任务
	xpcall(fn, function(msg) LOG_ERROR(msg) end)
	-- 重置定时器
	this.schedule(on_timer, interval, 1)
end

-------------------------------------------------
--- 服务接口
-------------------------------------------------

-- 服务初始化
function COMMAND.on_init(configure)
	-- 按配置构造排行榜对象
	for k, v in pairs(configure) do
		local m = Rank.new(k, v.order, v.uplimit, v.is_not_user)
		if m ~= nil then
			m:load()
			ranks[k] = m
		else
			error("rankd.on_init() configure failed!!!")
		end
	end
	-- 启动定时器
	this.schedule(on_timer, interval, 1)
end

-- 服务退出
function COMMAND.on_exit()
	for _, v in pairs(ranks) do
		v:save()
	end
end

-- 获取排行榜上榜数量
function COMMAND.on_count(alias)
	local rank = ranks[alias]
	if rank ~= nil then
		return rank.count
	else
		return 0
	end
end

-- 更新数据（返回排行变更列表）
function COMMAND.on_update(alias, uid, score, param)
	local rank = ranks[alias]
	if rank ~= nil then
		-- 更新社交排行信息
		if not rank.is_not_user then
			local name = "update_user"
			local data =
			{
				charts_data =
				{
					[alias] = score
				}
			}
			nova.send(GLOBAL.WS_NAME.SOCIALD, "lua", name, uid, data)
		end
		-- 更新全服排行信息
		return rank:update(uid, score, param)
	else
		return 0
	end
end

-- 获取角色排名
function COMMAND.on_revrank(alias, uid)
	local rank = ranks[alias]
	if rank ~= nil then
		return rank:revrank(uid)
	else
		return nil
	end
end

function COMMAND.on_revrank_withscore(alias, uid)
	local rank = ranks[alias]
	if rank ~= nil then
		return rank:revrank_withscore(uid)
	else
		return nil
	end
end

-- 获取指定区间内排名信息
function COMMAND.on_revrange(alias, spoint, epoint)
	local rank = ranks[alias]
	if rank ~= nil then
		return rank:revrange(spoint, epoint)
	else
		return nil
	end
end

-- 检索符合条件的uid列表
function COMMAND.select_condition_uids(alias, uid, filter_list, onlines_list, max_num)
    local rank = ranks[alias]
	if rank ~= nil then
		return rank:select_condition_uids(uid, filter_list, onlines_list, max_num)
	else
		return nil
	end
end

-- 清空排行榜
function COMMAND.on_cleanup(alias)
	local function cleanup(alias)
		local rank = ranks[alias]
		if rank ~= nil then
			rank.count   = 0
			rank.dirty   = true
			rank.ranking = {}
			rank.members = {}
			-- 更新社交排行信息
			if not rank.is_not_user then
				nova.send(GLOBAL.WS_NAME.SOCIALD, "lua", "clear_charts_data", alias)
			end
		end
	end
	if type(alias) == "table" then
		for _, v in pairs(alias) do
			cleanup(v)
		end
	else
		cleanup(alias)
	end
	return 0
end

-- 清空指定角色排行
function COMMAND.on_reset(alias, uid)
	local rank = ranks[alias]
	if rank ~= nil then
		this.send("on_update", alias, uid, 0)
	elseif alias == "all" then
		for k,_ in pairs(ranks) do
			this.send("on_update", k, uid, 0)
		end
	end
end

-------------------------------------------------
--- 服务注册
-------------------------------------------------
service.register({
	-- 消息广播类型
	theme = GLOBAL.PROTO_TYPE.TERMINAL,
	-- 垃圾收集标记
	collect = "false",
	-- 服务接口注册
	CMD = COMMAND,
})
