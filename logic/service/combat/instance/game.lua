--
-- 对战战场服务
--
local service = require "service_factory.service"
local skynet  = require "skynet"
local ENUM    = require "config.gameenum"
-- 底层驱动加载
local userdriver = require "driver.userdriver"

local COMMAND = {}
-----------------------------------------------------------
--- 服务常量
-----------------------------------------------------------

-- 所有比赛集合
local games = {}

-- 服务状态枚举
local ESTATES =
{
	PREPARE		= 1,		-- 赛前准备阶段
	LOADING		= 2,		-- 场景加载阶段
	READY		= 3,		-- 比赛预备阶段
	RUNNING		= 4,		-- 正式比赛阶段
	FINISHED	= 5,		-- 比赛结束阶段
}

-- 赛前准备时间（秒）
local GAME_PREPARE_DURATION = 60

-- 比赛预备时长（秒）
local GAME_READY_DURATION   = 30

-- 默认比赛时长（秒）
local GAME_MATCH_DURATION   = 600

-- 比赛结算时长（秒）
local GAME_FINISH_DURATION  = 150

-----------------------------------------------------------
--- 赛道选择
-----------------------------------------------------------

-----------------------------------------------------------
---  内部逻辑
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
	-- 设置战场数据
	member.game =
	{
		score          = 0,					-- 比赛得分
	}
	return member
end

-- 战场统计更新
function Member:submit(values)
	
end

-- 战场消息通知
-- 1. 消息名称
-- 2. 消息内容
function Member:notify(name, data)
	-- 过滤掉线成员
	if self.online ~= 1 then
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
	game.alias    = alias				-- 战场id
	game.state    = ESTATES.PREPARE		-- 战场状态
	game.stime    = 0					-- 开始时间（滴答 = 10毫秒）
	game.etime    = 0					-- 结束时间（滴答 = 10毫秒）
	game.members  = {}					-- 成员列表
	for _, user in pairs(users) do		
		-- 加入战场
		local member = game:join(Member.new(user))
		if member == nil then
			return nil
		end
	end
	
	games[alias] = game
	return game
end

-- 关闭战场（延迟关闭）
function Game:close()
	-- 关闭战场通知
	if not self.closed then
		-- 设置关闭标志
		self.closed = true
		-- 移除战场成员
		for _, member in pairs(self.members) do
			self:quit(member.uid)
		end		
	end
	
	games[self.id] = nil
end

-- 加入战场
function Game:join(member)
	if member ~= nil then
		-- 加入服务
		local errcode = enter_environment()
		if errcode ~= 0 then
			return nil
		end
		table.insert(self.members, member)
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
			leave_environment()
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
			table.insert(list,member.uid)
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
		snapshot.portrait_box_id = member.portrait_box_id
		return snapshot
	end
	-- 构造信息
	local data =
	{
		members  = {},
	}
	for _, v in pairs(self.members) do
		table.insert(data.members, snapshot(v))
	end
	return data
end

-- 创建战场
function COMMAND.on_create(alias, major, minor, users)
  local result = {}
  -- 构造战场
  local game = Game.new(alias, major, minor, users)
  if game == nil then
    return ERRCODE.GAME_CREATE_FAILED
  end
  
  return 0
end

-- 关闭战场（通过'game.close'间接调用）
-- 1. 战场编号
function COMMAND.on_close(alias)  
  return 0
end

-- 离开战场（成员强制离开）
-- 1. 战场编号
-- 2. 角色编号
function COMMAND.on_leave(alias, uid)
  local game = games[alias]
  assert(game, "game.on_leave() : game not exists!!!")
  
  local member = game:quit(uid)
  if member ~= nil then
    -- 战斗结算（战场未完成状态）
    if game.state ~= ESTATES.FINISHED then
      local vdata =
      {
        	score      = 0,                           -- 获得积分
      }
      member:notify("on_game_complete", vdata)
    end
    -- 清理战场
    if game:empty() then
      game:close()
    else
      game:broadcast("game_player_quit", {uid = member.uid})
    end
  end
  return 0
end


-- 战场数据同步（数据不经过战场可以提高数据转发效率）
-- 1. 战场编号
-- 2. 角色编号
-- 3. 战场数据
function COMMAND.on_game_update(alias, uid, data)
  local game = games[alias]
  assert(game, "on_game_update() : game not exists!!!")
  
  -- 成员检查
  local member = game:get(uid)
  if member == nil then
    return ERRCODE.GAME_NOT_MEMBER
  end
  
  game:broadcast("game_update_notify", data)
  return 0
end

-- 战场数据转发
-- 1. 战场编号
-- 2. 数据名称
-- 3. 数据内容
function COMMAND.on_game_forward(alias, name, data)
  local game = games[alias]
  assert(game, "on_game_update() : game not exists!!!")
  
  game:broadcast(name, data)
  return 0
end

-----------------------------------------------------------
--- 结算相关逻辑
-----------------------------------------------------------

-- 战场关闭（延时关闭，确保用户成功返回组队服务）
-- 1. 战场编号
function COMMAND.game_finish_complete(alias)
  local game = games[alias]
  assert(game, "game_finish_complete() : game not exists!!!")
  
  if game.state == ESTATES.FINISHED then
    -- 关闭战场
    game:close()
  end  
end

-- 成员掉线通知
-- 1. 战场编号
function COMMAND.on_disconnect(alias, uid)
  local game = games[alias]
  assert(game, "on_disconnect() : game not exists!!!")
  
  game:disconnect(uid)
  game:broadcast("game_disconnect_notify", {uid = uid})
  return 0
end

-- 成员重连通知
-- 1. 战场编号
function COMMAND.on_reconnect(alias, uid)
  local game = games[alias]
  assert(game, "on_disconnect() : game not exists!!!")
  
  local member = game:reconnect(uid)
  
  if not member then
    return ERRCODE.GAME_NOT_MEMBER
  end
  return 0
end

-----------------------------------------------------------
--- 注册战场服务
-----------------------------------------------------------

local handler = {}

-- 消息分发逻辑
-- 1. 消息来源
-- 2. 消息类型
-- 3. 消息内容
function handler.command_handler(source, cmd, ...)
	local fn = COMMAND[cmd]
	if fn then
		return fn(source, ...)
	else
		ERROR("svcmanager : command[%s] can't find!!!", cmd)
	end
end

service.start(handler)
