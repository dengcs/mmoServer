--
-- 对战房间模型
--
local skynet   	= require "skynet_ex"
local utils 	= require "combat.utils"

-----------------------------------------------------------
--- 内部常量/内部逻辑
-----------------------------------------------------------

-- 队伍最大成员数量
local ROOM_MAX_MEMBERS = 3

-- 状态枚举（成员/队伍）
local ESTATES = 
{
	PREPARE = 1,	-- 准备中
	READY   = 2,	-- 已就绪
	RUNNING = 3,	-- 比赛中
}

-- 编号序列
local SEQUENCE = 10000000

-- 编号分配逻辑
local function allocid()
	SEQUENCE = SEQUENCE + 1
	return SEQUENCE
end

-- 状态转换判断
-- 1. 当前状态
-- 2. 目标状态
local function convertible(ostate, nstate)
  -- 状态转换表
  local map = 
  {
	[ESTATES.PREPARE] = { ESTATES.READY   },
	[ESTATES.READY  ] = { ESTATES.RUNNING },
	[ESTATES.RUNNING] = { ESTATES.PREPARE , ESTATES.READY},
  }
  -- 状态转换判断
  for _, v in pairs(map[ostate] or {}) do
	if v == nstate then
	  return true
	end
  end
  return false
end

-----------------------------------------------------------
--- 成员模型
-----------------------------------------------------------
local Member = {}
Member.__index = Member

-- 构造成员对象
function Member.new(vdata)
	if vdata and next(vdata) then
		local member =
		{
			agent				= vdata.agent,			-- 角色句柄
			pid             	= vdata.pid,			-- 角色编号
			sex             	= vdata.sex,			-- 角色性别
			nickname        	= vdata.nickname,		-- 角色昵称
			portrait        	= vdata.portrait,		-- 角色头像
			portrait_box 		= vdata.portrait_box,	-- 角色像框
			ulevel          	= vdata.ulevel,			-- 角色等级
			vlevel          	= vdata.vlevel,			-- 贵族等级
			score           	= vdata.score,			-- 角色积分
			state           	= ESTATES.PREPARE,		-- 角色状态
			robot		   		= vdata.robot,			-- 机器人标识
			place		   		= vdata.place,			-- 角色座次
			online 				= 0,					-- 在线状态
		}
		return setmetatable(member, Member)
	end
end

-- 判断成员是否准备中
function Member:prepare()
	if self.state == ESTATES.PREPARE then
		return true
	else
		return false
	end
end

-- 判断成员是否已就绪
function Member:ready()
	if self.state == ESTATES.READY then
		return true
	else
		return false
	end
end

-- 判断成员是否比赛中
function Member:running()
	if self.state == ESTATES.RUNNING then
		return true
	else
		return false
	end
end

-- 成员快照
function Member:snapshot()
	local snapshot =
	{
		pid        			= self.pid,
		sex        			= self.sex,
		nickname   			= self.nickname,
		portrait   			= self.portrait,
		ulevel     			= self.ulevel,
		vlevel     			= self.vlevel,
		place				= self.place,
		state				= self.state,
		portrait_box 		= self.portrait_box,
		robot				= self.robot,
		agent				= self.agent,
	}
	return snapshot
end

function Member:snapshotToC()
	local snapshot =
	{
		pid        			= self.pid,
		sex        			= self.sex,
		nickname   			= self.nickname,
		portrait   			= self.portrait,
		ulevel     			= self.ulevel,
		vlevel     			= self.vlevel,
		place				= self.place,
		state				= self.state,
		portrait_box 		= self.portrait_box,
		online				= self.online,
	}
	return snapshot
end

-- 消息通知
function Member:notify(name, data)
	-- 过滤机器人
	if self.robot then
		return
	end
	if self.agent ~= nil then
		skynet.send(self.agent, "lua", "on_common_notify", name, data)
	else
		this.usersend(self.pid, "on_common_notify", name, data)
	end
end

-- 状态转换
function Member:convert(alias)
  local state = assert(ESTATES[alias])
  if (self.state ~= state) then
	if convertible(self.state, state) then
	  self.state = state
	else
		LOG_ERROR("member.convert(%s) failed!!!", alias)
	end
  end
end

function Member:disconnect()
	self.online = this.time()
end

function Member:reconnect()
	self.online = 0
end

-----------------------------------------------------------
--- 队伍模型
-----------------------------------------------------------
local Team = {}
Team.__index = Team

-- 构造队伍
-- 1. 创建者信息
function Team.new(vdata)
	local team_dt =
	{
		id      	= allocid(),				-- 队伍编号（顺序递增）
		state   	= ESTATES.PREPARE,			-- 队伍状态
		xtime   	= 0,						-- 匹配时间
		count	 	= 0,						-- 成员数量
		channel 	= 0,						-- 频道
		members 	= {},						-- 成员列表
	}

	local team = setmetatable(team_dt, Team)
	-- 成员加入队伍
	local member = team:join(vdata)
	if not member then
		return nil
	else
		return team
	end
end

-- 判断队伍是否准备中
function Team:prepare()
	if self.state == ESTATES.PREPARE then
		return true
	else
		return false
	end
end

-- 判断队伍是否已就绪
function Team:ready()
	if self.state == ESTATES.READY then
		return true
	else
		return false
	end
end

-- 判断队伍是否比赛中
function Team:running()
	if self.state == ESTATES.RUNNING then
		return true
	else
		return false
	end
end

-- 队伍是否可以开始
function Team:can_start()
	if self.count >= ROOM_MAX_MEMBERS then
		for _, member in pairs(self.members) do
			if member:ready() == false then
				return false
			end
		end
		return true
	end
	return false
end

-- 队伍快照（用于推送到战场）
function Team:snapshot()
	local snapshot =
	{
		teamid 		= self.id,
		channel 	= self.channel,
		state		= self.state,
		members		= {},
	}

	for _, member in pairs(self.members or {}) do
		snapshot.members[member.place] = member:snapshot()
	end

	return snapshot
end

function Team:snapshotToC()
	local snapshot =
	{
		teamid 		= self.id,
		channel 	= self.channel,
		state		= self.state,
		members		= {},
	}

	for _, member in pairs(self.members or {}) do
		table.insert(snapshot.members, member:snapshotToC())
	end

	return snapshot
end

-- 指定成员
function Team:get(pid)
	return self.members[pid]
end

-- 加入队伍
function Team:join(vdata)
	if self.count >= ROOM_MAX_MEMBERS then
		return
	end

	if not self:prepare() then
		return
	end

	-- 成员加入队伍
	local member = Member.new(vdata)
	if member ~= nil then
		self.members[member.pid] = member

		self.count = self.count + 1
		member.place = self.count
		member:convert("READY")
		self:auto_ready()
		self:synchronize()
	end
	return member
end

function Team:auto_ready()
	local count = 0
	for _, member in pairs(self.members) do
		if member:ready() then
			count = count + 1
		end
	end

	if count == ROOM_MAX_MEMBERS then
		self:convert("READY")
	end
end

-- 离开队伍
function Team:remove(pid)
	-- 移除队伍成员
	local member = self.members[pid]
	if member then
		self.members[pid] = nil
		self.count = self.count - 1

		self:synchronize()
	end

	return member
end

-- 消息广播
function Team:broadcast(name, data)
	for _, member in pairs(self.members) do
		member:notify(name, data)
	end
end

-- 开始匹配（快速状态转换）
function Team:start()
	self:convert("RUNNING")
	self.xtime = this.time()

	utils.start(1,1,self:snapshot())

	return true
end

function Team:robot_ready()
	for _, member in pairs(self.members) do
		if member.robot and member:prepare() then
			member:convert("READY")
		end
	end
	self:auto_ready()
end

function Team:clean()
	for _, member in pairs(self.members) do
		if member.online ~= 0 then

		end
	end
end

-- 通知匹配（快速状态转换）
function Team:stop()
	self:convert("PREPARE")
	self.xtime = 0
	return true
end

-- 结算
function Team:settle(data)
	local win_idx 	= data.idx
	local double	= data.double
	local lord		= data.lord
	for _, member in pairs(self.members) do
		if member.place == lord then
			if member.place == win_idx then
				this.logic_send(member.pid, "player_settle", true, self.channel, double)
			else
				this.logic_send(member.pid, "player_settle", false, self.channel, double)
			end
		else
			if win_idx == lord then
				this.logic_send(member.pid, "player_settle", false, self.channel, double)
			else
				this.logic_send(member.pid, "player_settle", true, self.channel, double)
			end
		end
	end
end

-- 等待时长（匹配等待时长）
function Team:duration()
	assert(self:ready())
	return math.max(0, this.time() - self.xtime)
end

-- 状态转换
function Team:convert(alias)
	local state = assert(ESTATES[alias])
	if (self.state ~= state) then
		if convertible(self.state, state) then
			self.state = state
			for _, member in pairs(self.members) do
				member:convert(alias)
			end
		else
			LOG_ERROR("team.convert(%s) failed!!!", alias)
		end
	end
end

-- 队伍等级（成员最高等级）
function Team:level()
	local maxlv = 0
	for _, member in pairs(self.members) do
		if member.ulevel > maxlv then
			maxlv = member.ulevel
		end
	end
	return maxlv
end

-- 队伍同步通知
function Team:synchronize()
	-- 房间同步逻辑
	local name = "room_synchronize_notify"
	self:broadcast(name, self:snapshotToC())
end

-- 掉线
function Team:disconnect(pid)
	local member = self.members[pid]
	if member then
		member:disconnect()
	end
end

-- 重连
function Team:reconnect(pid)
	local member = self.members[pid]
	if member then
		member:reconnect()
	end
end

-----------------------------------------------------------
--- 房间赛频道模型
-----------------------------------------------------------
local Channel = {}
Channel.__index = Channel

-- 构建频道
function Channel.new(id)
	local channel =
	{
		id		= id,
		teams   = {},	-- 频道房间列表
	}
	return setmetatable(channel, Channel)
end

---- 消息广播
--function Channel:broadcast(name, data)
--	for k, v in pairs(self.onlines) do
--		this.usersend(k, "on_common_notify", name, data)
--	end
--end

-- 获取队伍
function Channel:get(tid)
	return self.teams[tid]
end

-- 创建队伍
function Channel:create(vdata)
	local team = Team.new(vdata)
	if team then
		team.channel		= self.id
		self.teams[team.id] = team
	end
	return team
end

-- 移除队伍
function Channel:remove(tid)
	local team = self.teams[tid]
	if team ~= nil then
		self.teams[tid] = nil
	end
	return team
end

-----------------------------------------------------------
--- 返回房间相关模型
-----------------------------------------------------------
return {Team = Team, Member = Member, Channel = Channel}
