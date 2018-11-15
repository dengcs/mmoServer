--
-- 对战组队模型
--
local skynet   		= require "skynet_ex"
local ENUM    		= require "config.gameenum"
local play_manager	= require "pdk.play_manager"

local tinsert 		= table.insert
local userdriver 	= skynet.userdriver()

local PLAYER_STATE_TYPE = ENUM.PLAYER_STATE_TYPE
local GAME_MEMBER_STATE = ENUM.GAME_MEMBER_STATE
local GAME_STATE		= ENUM.GAME_STATE
local PLAY_EVENT		= ENUM.PLAY_EVENT

-----------------------------------------------------------
--- 内部常量/内部逻辑
-----------------------------------------------------------

-- 加入战场服务
-- 1. 角色编号
-- 2. 战场别名
-- 3. 强制标志
local function enter_environment(uid, alias, force)
	local errcode, retval = userdriver.usercall(uid, "on_enter_environment", PLAYER_STATE_TYPE.PLAYER_STATE_GAME, alias, force)
	if not retval then
		errcode = ERRCODE.GAME_ENTERENV_FAILED
	end
	return errcode
end

-- 离开战场服务
-- 1. 角色编号
-- 2. 战场别名
local function leave_environment(uid, alias)
	local errcode, retval = userdriver.usercall(uid, "on_leave_environment", PLAYER_STATE_TYPE.PLAYER_STATE_GAME, alias)
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
	local member = {}
	setmetatable(member, Member)
	-- 设置基础数据
	member.agent      	= vdata.agent					-- 角色句柄
	member.uid        	= vdata.uid						-- 角色编号
	member.sex        	= vdata.sex						-- 角色性别
	member.nickname   	= vdata.nickname				-- 角色昵称
	member.portrait   	= vdata.portrait				-- 角色头像
	member.ulevel     	= vdata.ulevel					-- 角色等级
	member.vlevel     	= vdata.vlevel					-- 贵族等级
	member.score      	= vdata.score					-- 角色积分
	member.state     	= GAME_MEMBER_STATE.ONLINE	-- 在线状态（1 - 在线， 2 - 离线， 3 - 退出）
	member.robot      	= vdata.robot					-- 是否是机器人
	member.place		= vdata.place					-- 角色座位
	member.portrait_box_id = vdata.portrait_box_id
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
	if self.state ~= GAME_MEMBER_STATE.ONLINE then
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

-- 成员快照
function Member:snapshot()
	local snapshot = {}
	snapshot.uid      	= self.uid
	snapshot.sex      	= self.sex
	snapshot.nickname 	= self.nickname
	snapshot.portrait 	= self.portrait
	snapshot.ulevel   	= self.ulevel
	snapshot.vlevel   	= self.vlevel
	snapshot.place		= self.place
	snapshot.state	  	= self.state
	snapshot.portrait_box_id = self.portrait_box_id
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
	local game = {}
	setmetatable(game, Game)

	-- 设置战场数据
	game.alias    	= alias							-- 战场id
	game.state    	= GAME_STATE.PREPARE		-- 战场状态
	game.stime    	= 0								-- 开始时间（滴答 = 10毫秒）
	game.etime    	= 0								-- 结束时间（滴答 = 10毫秒）
	game.members  	= {}							-- 成员列表
	game.channel	= data.channel
	game.teamid		= data.teamid
	game.owner		= data.owner
	for _, user in pairs(data.members) do
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
	self.play_mgr = play_manager.new()
	local functions = self:auth_functions_to_manager()
	self.play_mgr:copy_functions_from_game(functions)
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
			v.state = GAME_MEMBER_STATE.QUIT
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

-- 判断是否空战场
function Game:empty()
	for _, member in pairs(self.members) do
		if member.state ~= GAME_MEMBER_STATE.QUIT then
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
			if v.state == GAME_MEMBER_STATE.QUIT then
				break
			end
			if v.uid == uid then
				member   = v
				v.state = GAME_MEMBER_STATE.OFFLINE
			end
		until(true)
	end
	return member
end

-- 成员重连
function Game:reconnect(uid)
	local member = nil
	for _, v in pairs(self.members) do
		if v.state ~= GAME_MEMBER_STATE.QUIT then
			if v.uid == uid then
				member = v
			end
			v.state = GAME_MEMBER_STATE.ONLINE
		end
	end
	return member
end

-- 内部事件
function Game:event(id, data)
	if id == PLAY_EVENT.GAME_OVER then
		for i, v in pairs(self.members) do
			if not v.robot then
				leave_environment(v.uid, self.alias)
			end
		end
		skynet.send(GLOBAL.SERVICE_NAME.GAME, "lua", "game_finish", self.alias, data)
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
				self:update(member.uid, data.data)
			end
		else
			member:notify(name, data)
		end
	end
end

function Game:uid_to_idx(uid)
	for idx, member in pairs(self.members) do
		if member.uid == uid then
			return idx
		end
	end
end

-- 构造赛前信息
function Game:snapshot()
	-- 构造信息
	local data =
	{
		owner	= self.owner,
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

function Game:update(uid, data)
	local idx = self:uid_to_idx(uid)
	if idx then
		self.play_mgr:update(idx, data)
	end
end

-----------------------------------------------------------
--- 返回游戏相关模型
-----------------------------------------------------------
return {Member = Member, Game = Game}
