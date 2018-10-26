--
-- 对战战场服务
--
local skynet  	= require "skynet"
local service 	= require "factory.service"
local ENUM    	= require "config.gameenum"
local model		= require "combat.gamemodel"

local COMMAND = {}
-----------------------------------------------------------
--- 服务常量
-----------------------------------------------------------

-- 所有比赛集合
local games = {}

-----------------------------------------------------------
---  内部逻辑
-----------------------------------------------------------

local Game = model.Game

-- 步进序号
local SEQUENCE  = 0

-- 生成编号(50位整数)
-- 1. 主类型
-- 2. 子类型
local function allocid(major, minor)
	SEQUENCE = SEQUENCE + 1
	return string.format("%x", ((major & 0xF) << 46) + ((minor & 0xF) << 42) + SEQUENCE)
end

-----------------------------------------------------------
--- 游戏服务接口
-----------------------------------------------------------
-- 创建战场
function COMMAND.on_create(major, minor, data)
	-- 构造别名
	local alias = allocid(major, minor)
	-- 构造战场
	local game = Game.new(alias, data)
	if game == nil then
		return ERRCODE.GAME_CREATE_FAILED
	end

	game:start()

	games[alias] = game
	return 0
end

-- 关闭战场（通过'game.close'间接调用）
-- 1. 战场编号
function COMMAND.on_close(alias)
	games[self.alias] = nil
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
		game:broadcast("game_quit__notify", {uid = member.uid})
		-- 清理战场
		if game:empty() then
			game:close(skynet.self())
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

	game:broadcast("game_update_notify", {data = data})
	return 0
end

-- 战场数据转发
-- 1. 战场编号
-- 2. 数据名称
-- 3. 数据内容
function COMMAND.on_game_forward(alias, name, data)
	local game = games[alias]
	assert(game, "on_game_forward() : game not exists!!!")

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

	if game.state == ENUM.GAME_STATE.FINISHED then
		-- 关闭战场
		game:close(skynet.self())
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
		return fn(...)
	else
		ERROR("svcmanager : command[%s] can't find!!!", cmd)
	end
end

service.start(handler)
