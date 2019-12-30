--
-- 对战战场服务
--
local skynet  	= require "skynet"
local service 	= require "factory.service"
local model		= require "combat.game"

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
local function alloc_id(major, minor)
	SEQUENCE = SEQUENCE + 1
	return string.format("%x", ((major & 0xF) << 46) + ((minor & 0xF) << 42) + SEQUENCE)
end

-----------------------------------------------------------
--- 游戏服务接口
-----------------------------------------------------------
-- 创建战场
function COMMAND.on_create(major, minor, data)
	-- 构造别名
	local alias = alloc_id(major, minor)
	-- 构造战场
	local game = Game.new(alias, data)
	if game == nil then
		return ERRCODE.GAME_CREATE_FAILED
	end

	game:start()

	games[alias] = game
	return 0
end

-- 1. 战场编号
function COMMAND.on_close(alias)
	games[alias] = nil
  	return 0
end

-- 离开战场（成员强制离开）
-- 1. 战场编号
-- 2. 角色编号
function COMMAND.on_leave(alias, pid)
	local game = games[alias]
	assert(game, "game.on_leave() : game not exists!!!")

	local member = game:quit(pid)
	if member ~= nil then
		game:broadcast("game_quit_notify", {pid = member.pid})
		-- 清理战场
		if game:empty() then
			games[alias] = nil
		end
	end
	return 0
end


-- 战场数据同步（数据不经过战场可以提高数据转发效率）
-- 1. 战场编号
-- 2. 角色编号
-- 3. 战场数据
function COMMAND.on_game_update(alias, pid, data)
	local game = games[alias]
	assert(game, "on_game_update() : game not exists!!!")

	-- 成员检查
	local member = game:get(pid)
	if member == nil then
		return ERRCODE.GAME_NOT_MEMBER
	end

	game:update(pid, data)

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

-- 战场关闭（延时关闭，确保用户成功返回组队服务）
-- 1. 战场编号
function COMMAND.game_finish(alias, data)
	local game = games[alias]
	assert(game, "game_finish: game not exists!!!")

	games[alias] = nil

	skynet.send(GLOBAL.SERVICE_NAME.ROOM, "lua", "on_game_finish", game.channel, game.teamid, data)
end

-----------------------------------------------------------
--- 重连相关逻辑
-----------------------------------------------------------

-- 成员掉线通知
-- 1. 战场编号
function COMMAND.on_disconnect(alias, pid)
	local game = games[alias]
	assert(game, "on_disconnect() : game not exists!!!")

	game:disconnect(pid)
	game:broadcast("game_disconnect_notify", {pid = pid})
	return 0
end

-- 成员重连通知
-- 1. 战场编号
function COMMAND.on_reconnect(alias, pid)
	local game = games[alias]
	assert(game, "on_disconnect() : game not exists!!!")

	local member = game:reconnect(pid)

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
		LOG_ERROR("svcmanager : command[%s] can't find!!!", cmd)
	end
end

service.start(handler)
