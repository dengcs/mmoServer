--
-- 对战组队模型
--
local skynet   		= require "skynet_ex"
local ENUM    		= require "config.gameenum"
local tinsert 		= table.insert
local userdriver 	= skynet.userdriver()

-----------------------------------------------------------
--- 内部常量/内部逻辑
-----------------------------------------------------------

-- 加入战场服务
-- 1. 角色编号
-- 2. 战场别名
-- 3. 强制标志
local function enter_environment(uid, alias, force)
	local errcode, retval = userdriver.usercall(uid, "on_enter_environment", ENUM.PLAYER_STATE_TYPE.PLAYER_STATE_GAME, alias, force)
	if not retval then
		errcode = (errcode ~= 0 and errcode) or ERRCODE.GAME_ENTERENV_FAILED
	end
	return errcode
end

-- 离开战场服务
-- 1. 角色编号
-- 2. 战场别名
local function leave_environment(uid, alias)
	local errcode, retval = userdriver.usercall(uid, "on_leave_environment", ENUM.PLAYER_STATE_TYPE.PLAYER_STATE_GAME, alias)
	if not retval then
		errcode = (errcode ~= 0 and errcode) or ERRCODE.GAME_LEAVEENV_FAILED
	end
	return errcode
end

-----------------------------------------------------------
--- 成员模型
-----------------------------------------------------------
local Member = {}
Member.__index = Member

-- 构造成员对象
-- 1. 参赛者信息
function Member.new(vdata)
	local member = {}
	setmetatable(member, Member)

	-- 设置基础数据
	member.portrait_box_id = vdata.portrait_box_id
	member.teamid     = vdata.teamid		-- 队伍编号
	member.agent      = vdata.agent			-- 角色句柄
	member.uid        = vdata.uid			-- 角色编号
	member.sex        = vdata.sex			-- 角色性别
	member.nickname   = vdata.nickname		-- 角色昵称
	member.portrait   = vdata.portrait		-- 角色头像
	member.ulevel     = vdata.ulevel		-- 角色等级
	member.vlevel     = vdata.vlevel		-- 贵族等级
	member.score      = vdata.score			-- 角色积分
	member.state      = 0					-- 角色状态（0 - 准备， 1 - 就绪）
	member.online     = 1					-- 在线状态（1 - 在线， 2 - 离线， 3 - 退出）
	member.robot      = vdata.robot			-- 是否是机器人
	-- 设置战场数据
	member.game =
	{
		score          = 0,					-- 比赛得分
	}
	return member
end

-- 战场消息通知
-- 1. 消息名称
-- 2. 消息内容
function Member:notify(name, data)
	-- 过滤掉线成员
	if self.online ~= 1 then
		return
	end
	-- 过滤机器人
	if self.robot then
		return
	end
	-- 战场消息通知
	if self.agent ~= nil then
		skynet.send(self.agent, "lua", "on_common_notify", name, data)
	else
		userdriver.usersend(self.uid, "on_common_notify", name, data)
	end
end

-----------------------------------------------------------
--- 战场模型
-----------------------------------------------------------
local Game = {}
Game.__index = Game

-- 构造战场
-- 1. 战场id
-- 2. 成员列表
function Game.new(alias, users)
	local game = {}
	setmetatable(game, Game)

	-- 设置战场数据
	game.alias    = alias						-- 战场id
	game.state    = ENUM.GAME_STATE.PREPARE		-- 战场状态
	game.stime    = 0							-- 开始时间（滴答 = 10毫秒）
	game.etime    = 0							-- 结束时间（滴答 = 10毫秒）
	game.members  = {}							-- 成员列表
	for _, user in pairs(users) do
		-- 加入战场
		local member = game:join(Member.new(user))
		if member == nil then
			return nil
		end
	end

	return game
end

-- 关闭战场（延迟关闭）
function Game:close(source)
	-- 关闭战场通知
	if not self.closed then
		-- 设置关闭标志
		self.closed = true
		-- 移除战场成员
		for _, member in pairs(self.members) do
			self:quit(member.uid)
		end
	end

	skynet.call(source, "lua", "on_close", self.alias)
end

-- 加入战场
function Game:join(member)
	if member ~= nil then
		-- 加入服务
		if not member.robot then
			local errcode = enter_environment(member.uid, self.alias)
			if errcode ~= 0 then
				return nil
			end
		end
		tinsert(self.members, member)
	end
	return member
end

-- 离开战场
function Game:quit(uid)
	local member = nil
	for _, v in pairs(self.members) do
		-- 成员离线处理
		if v.uid == uid then
			v.online = 3
			-- 记录退出成员
			member = v
			if not v.robot then
				leave_environment(uid, self.alias)
			end
			break
		end
	end
	return member
end

-- 指定成员
function Game:get(uid)
	for _, member in pairs(self.members) do
		if member.uid == uid then
			return member
		end
	end
	return nil
end

-- 队伍成员列表
function Game:get_member_list(teamid)
	local list = {}
	for _, member in pairs(self.members) do
		if teamid == member.teamid then
			tinsert(list,member.uid)
		end
	end
	return list
end

-- 判断是否空战场
function Game:empty()
	for _, member in pairs(self.members) do
		if member.online ~= 3 then
			return false
		end
	end
	return true
end

-- 成员掉线
function Game:disconnect(uid)
	local member = nil
	for _, v in pairs(self.members) do
		repeat
			if v.online == 3 then
				break
			end
			if v.uid == uid then
				member   = v
				v.online = 2
			end
		until(true)
	end
	return member
end

-- 成员重连
function Game:reconnect(uid)
	local member = nil
	for _, v in pairs(self.members) do
		if v.online ~= 3 then
			if v.uid == uid then
				member = v
			end
			v.online = 1
		end
	end
	return member
end

-- 消息广播
function Game:broadcast(name, data)
	for _, member in pairs(self.members) do
		member:notify(name, data)
	end
end

-- 构造赛前信息
function Game:snapshot()
	-- 成员快照
	local function snapshot(member)
		local snapshot = {}
		snapshot.teamid   = member.teamid
		snapshot.uid      = member.uid
		snapshot.sex      = member.sex
		snapshot.nickname = member.nickname
		snapshot.portrait = member.portrait
		snapshot.ulevel   = member.ulevel
		snapshot.vlevel   = member.vlevel
		snapshot.state	  = member.state
		snapshot.portrait_box_id = member.portrait_box_id
		return snapshot
	end
	-- 构造信息
	local data =
	{
		state = self.state,
		members  = {},
	}
	for _, v in pairs(self.members) do
		tinsert(data.members, snapshot(v))
	end
	return data
end

-- 开始游戏
function Game:start()
	self:broadcast("game_start_notify", self:snapshot())
end

-----------------------------------------------------------
--- 返回组队模型
-----------------------------------------------------------
return {Member = Member, Game = Game}
