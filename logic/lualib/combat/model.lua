--
-- 对战组队模型
--
local skynet   = require "skynet_ex"

local userdriver = skynet.userdriver()

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
	local member = {}
	setmetatable(member, Member)
	-- 设置成员数据
	member.uid             = vdata.uid				-- 角色编号
	member.sex             = vdata.sex				-- 角色性别
	member.nickname        = vdata.nickname			-- 角色昵称
	member.portrait        = vdata.portrait			-- 角色头像
	member.portrait_box_id = vdata.portrait_box_id	-- 角色像框
	member.ulevel          = vdata.ulevel			-- 角色等级
	member.vlevel          = vdata.vlevel			-- 贵族等级
	member.score           = vdata.score			-- 角色积分
	member.state           = ESTATES.PREPARE		-- 角色状态
	return member
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

-- 成员快照（用于推送到战场）
function Member:snapshot()
	local snapshot = 
	{
		uid        = self.uid,
		sex        = self.sex,
		nickname   = self.nickname,
		portrait   = self.portrait,
		ulevel     = self.ulevel,
		vlevel     = self.vlevel,
		score      = self.score,
	}
	return snapshot
end

-- 消息通知
function Member:notify(name, data)	
	userdriver.usersend(self.uid, "on_common_notify", name, data)
end

-- 状态转换
function Member:convert(alias)
  local state = assert(ESTATES[alias])
  if (self.state ~= state) then
    if convertible(self.state, state) then
      self.state = state
    else
      assert(nil, string.format("member.convert(%s) failed!!!", alias))
    end
  end
end

-----------------------------------------------------------
--- 队伍模型
-----------------------------------------------------------
local Team = {}
Team.__index = Team

-- 构造队伍
-- 1. 创建者信息
function Team.new(vdata)
	local team = {}
	
	setmetatable(team, Team)
	
	-- 设置队伍数据
	team.id      = allocid()					-- 队伍编号（顺序递增）
	team.owner   = vdata.uid					-- 领队编号
	team.state   = ESTATES.PREPARE				-- 队伍状态
	team.xtime   = 0							-- 匹配时间
	team.weight  = 0							-- 匹配权重
	team.places  = {}							-- 座位信息
	team.members = {}							-- 成员列表
	for i = 1, ROOM_MAX_MEMBERS do
		table.insert(team.places, {id = i})
	end
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

-- 队伍容量
function Team:capacity()
	local capacity = 0
	for _, v in pairs(self.places) do
		if not v.locked then
			capacity = capacity + 1
		end
	end
	return capacity
end

-- 成员数量
function Team:size()
	local count = 0
	for _, v in pairs(self.members) do
		count = count + 1
	end
	return count
end

-- 指定成员
function Team:get(uid)
	for _, v in pairs(self.members) do
		if v.uid == uid then
			return v
		end
	end
	return nil
end

-- 加入队伍
function Team:join(vdata)
	-- 查找空闲座位
	local place = nil
	for _, v in pairs(self.places) do
		if not v.member then
			place = v
			break
		end
	end
	if place == nil then
		return nil
	end
	-- 成员加入队伍
	local member = Member.new(vdata)
	if member ~= nil then
		place.member             = member
		self.members[member.uid] = member
	end
	return member
end

-- 离开队伍
function Team:quit(uid)
	-- 移除队伍成员
	local member = nil
	for _, v in pairs(self.places) do
		if (v.member ~= nil) and (v.member.uid == uid) then
			member            = v.member
			v.member          = nil
			self.members[uid] = nil
			break
		end
	end
	-- 分发队伍判断
	local effective = false
	for _, v in pairs(self.places) do
		if (v.member ~= nil) then
			effective = true
			break
		end
	end
	if not effective then
		-- 清空队伍
		self.places  = {}
		self.members = {}
	else
		-- 转移队长权限
		if (member ~= nil) and (member.uid == self.owner) then
			for _, v in pairs(self.members) do
					self.owner = v.uid
					if v:ready() then
						v:convert("PREPARE")
					end
					break
			end
		end
	end
	return member
end

-- 消息广播
function Team:broadcast(name, data)
	for _, v in pairs(self.members) do
		v:notify(name, data)
	end
end

-- 开始匹配（快速状态转换）
function Team:start()
	self.state = ESTATES.READY
	self.xtime = os.time()
	return true
end

-- 通知匹配（快速状态转换）
function Team:stop()
	self.state = ESTATES.PREPARE
	self.xtime = 0
	return true
end

-- 等待时长（匹配等待时长）
function Team:duration()
	assert(self:ready())
	return math.max(0, os.time() - self.xtime)
end

-- 状态转换
function Team:convert(alias)
	local state = assert(ESTATES[alias])
	if (self.state ~= state) then
		if convertible(self.state, state) then
			self.state = state
		else
			assert(nil, string.format("team.convert(%s) failed!!!", alias))
		end
	end
end

-- 队伍等级（成员最高等级）
function Team:level()
	local maxlv = 0
	for _, v in pairs(self.members) do
		if v.ulevel > maxlv then
			maxlv = v.ulevel
		end
	end
	return maxlv
end

-----------------------------------------------------------
--- 返回组队模型
-----------------------------------------------------------
return {Team = Team, Member = Member}
