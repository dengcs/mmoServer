--
-- 对战组队模型
--
local skynet   		= require "skynet_ex"
local ENUM    		= require "config.enum"
local play_manager	= require "pdk.play_manager"

local tinsert 		= table.insert

local PLAYER_STATE_TYPE = ENUM.PLAYER_STATE_TYPE
local GAME_STATE		= ENUM.GAME_STATE
local PLAY_EVENT		= ENUM.PLAY_EVENT

-----------------------------------------------------------
--- 内部常量/内部逻辑
-----------------------------------------------------------

-- 加入战场服务
-- 1. 角色编号
-- 2. 战场别名
-- 3. 强制标志
local function enter_environment(pid, alias, force)
	local errcode, retval = this.usercall(pid, "on_enter_environment", PLAYER_STATE_TYPE.PLAYER_STATE_GAME, alias, force)
	if not retval then
		errcode = ERRCODE.GAME_ENTERENV_FAILED
	end
	return errcode
end

-- 离开战场服务
-- 1. 角色编号
-- 2. 战场别名
local function leave_environment(pid, alias)
	local errcode, retval = this.usercall(pid, "on_leave_environment", PLAYER_STATE_TYPE.PLAYER_STATE_GAME, alias)
	if not retval then
		errcode = ERRCODE.GAME_LEAVEENV_FAILED
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
	local member =
	{
		agent      		= vdata.agent,					-- 角色句柄
		pid        		= vdata.pid,					-- 角色编号
		sex        		= vdata.sex,					-- 角色性别
		nickname   		= vdata.nickname,				-- 角色昵称
		portrait   		= vdata.portrait,				-- 角色头像
		ulevel     		= vdata.ulevel,					-- 角色等级
		vlevel     		= vdata.vlevel,					-- 贵族等级
		score      		= vdata.score,					-- 角色积分
		online     		= 0,							-- 在线状态
		robot      		= vdata.robot,					-- 是否是机器人
		place			= vdata.place,					-- 角色座位
		portrait_box 	= vdata.portrait_box,
		game 			= {score = 0},					-- 比赛得分
	}
	return setmetatable(member, Member)
end

-- 战场消息通知
-- 1. 消息名称
-- 2. 消息内容
function Member:notify(name, data)
	-- 过滤掉线成员
	if self.online ~= 0 then
		return
	end
	-- 过滤机器人
	if self.robot then
		return
	end
	-- 战场消息通知
	if self.agent then
		skynet.send(self.agent, "lua", "on_common_notify", name, data)
	else
		this.usersend(self.pid, "on_common_notify", name, data)
	end
end

-- 成员快照
function Member:snapshot()
	local snapshot =
	{
		pid      		= self.pid,
		sex      		= self.sex,
		nickname 		= self.nickname,
		portrait 		= self.portrait,
		ulevel   		= self.ulevel,
		vlevel   		= self.vlevel,
		place			= self.place,
		online	  		= self.online,
		portrait_box 	= self.portrait_box,
	}
	return snapshot
end

-----------------------------------------------------------
--- 战场模型
-----------------------------------------------------------
local Game = {}
Game.__index = Game

-- 构造战场
-- 1. 战场id
-- 2. 成员列表
function Game.new(alias, data)
	local game_dt =
	{
		alias    	= alias,							-- 战场id
		state    	= GAME_STATE.PREPARE,				-- 战场状态
		stime    	= 0,								-- 开始时间（滴答 = 10毫秒）
		etime    	= 0,								-- 结束时间（滴答 = 10毫秒）
		members  	= {},								-- 成员列表
		channel		= data.channel,
		teamid		= data.teamid,
	}

	local game = setmetatable(game_dt, Game)
	for _, user in ipairs(data.members) do
		-- 加入战场
		local member = game:join(Member.new(user))
		if member == nil then
			return nil
		end
	end

	game:init_play_mgr()

	return game
end

function Game:init_play_mgr()
	self.play_mgr = play_manager.new(self.channel)
	self.play_mgr:init()
	local functions = self:auth_functions_to_manager()
	self.play_mgr:copy_functions_from_game(functions)
end

-- 封装函数给玩法模块调用
function Game:auth_functions_to_manager()
	local function broadcast(data)
		self:broadcast("game_update_notify", {data = data})
	end

	local function notify(idx, data)
		self:notify(idx, "game_update_notify", {data = data})
	end

	local function event(id, data)
		self:event(id, data)
	end

	local functions = {}
	functions.broadcast = broadcast
	functions.notify = notify
	functions.event = event

	return functions
end

-- 加入战场
function Game:join(member)
	if member ~= nil then
		-- 加入服务
		if not member.robot then
			local errcode = enter_environment(member.pid, self.alias)
			if errcode ~= 0 then
				return nil
			end
		end
		tinsert(self.members, member)
	end
	return member
end

-- 指定成员
function Game:get(pid)
	for _, member in pairs(self.members) do
		if member.pid == pid then
			return member
		end
	end
	return nil
end

-- 判断是否空战场
function Game:empty()
	for _, member in pairs(self.members) do
		if member.online == 0 then
			return false
		end
	end
	return true
end

-- 成员掉线
function Game:disconnect(pid)
	for _, member in pairs(self.members) do
		if member.pid == pid then
			member.online = this.time()
		end
	end
end

-- 成员重连
function Game:reconnect(pid)
	for _, member in pairs(self.members) do
		if member.pid == pid then
			member.online = 0
		end
	end
end

-- 游戏结束
function Game:over(data)
	for _, member in pairs(self.members) do
		if not member.robot then
			leave_environment(member.pid, self.alias)
		end
	end
	skynet.send(GLOBAL.SERVICE_NAME.GAME, "lua", "game_finish", self.alias, data)
end

-- 内部事件
function Game:event(id, data)
	if id == PLAY_EVENT.GAME_OVER then
		self:over(data)
	end
end

-- 消息广播
function Game:broadcast(name, data)
	for _, member in pairs(self.members) do
		member:notify(name, data)
	end
end

-- 推送消息给某个玩家
function Game:notify(idx, name, data)
	local member = self.members[idx]
	if member then
		if member.robot then
			if name == "game_update_notify" then
				self:update(member.pid, data.data)
			end
		else
			member:notify(name, data)
		end
	end
end

function Game:pid_to_idx(pid)
	for idx, member in pairs(self.members) do
		if member.pid == pid then
			return idx
		end
	end
end

-- 构造赛前信息
function Game:snapshot()
	-- 构造信息
	local data =
	{
		state 	= self.state,
		channel	= self.channel,
		teamid	= self.teamid,
		members = {},
	}
	for _, v in pairs(self.members) do
		tinsert(data.members, v:snapshot())
	end
	return data
end

-- 开始游戏
function Game:start()
	self:broadcast("game_start_notify", self:snapshot())
	self.play_mgr:shuffle_and_deal()
end

function Game:update(pid, data)
	local idx = self:pid_to_idx(pid)
	if idx then
		self.play_mgr:update(idx, data)
	end
end

-----------------------------------------------------------
--- 返回游戏相关模型
-----------------------------------------------------------
return {Member = Member, Game = Game}
