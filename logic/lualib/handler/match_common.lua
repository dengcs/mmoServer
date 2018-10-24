--
-- 组队比赛公共部分代码
--
local skynet  = require "skynet"
local ENUM    = require "config.gameenum"
local HANDLER = {}
local REQUEST = {}
local COMMAND = {}


-----------------------------------------------------------
--- 服务公共回调
-----------------------------------------------------------

-- 变更角色状态
local function change_player_state(player, state, param)
	-- 变更角色状态
	player.state = state
	player.scene = param
end

-- 角色状态变化通知（服务通知角色角色进入指定场景）
-- 1. 场景状态（角色进入场景后的新状态）
-- 2. 场景参赛（队伍编号或战场编号）
-- 3. 强制标志
function COMMAND:on_enter_environment(state, param, force)
	local player = self.user:get("Player")
	local switch =
	{
		-- 角色加入战场
		[ENUM.PLAYER_STATE_TYPE.PLAYER_STATE_GAME] = function(player, param, force)
			if ENUM.inspect_player_idle(player) or force then
				change_player_state(player, ENUM.PLAYER_STATE_TYPE.PLAYER_STATE_GAME, param)
				return true
			else
				return false
			end
		end,
		-- 角色加入房间
		[ENUM.PLAYER_STATE_TYPE.PLAYER_STATE_ROOM] = function(player, param, force)
			if ENUM.inspect_player_idle(player) or force then
				change_player_state(player, ENUM.PLAYER_STATE_TYPE.PLAYER_STATE_ROOM, param)
				return true
			else
				return false
			end
		end,
		-- 角色加入对战
		[ENUM.PLAYER_STATE_TYPE.PLAYER_STATE_PVP] = function(player, param, force)
			if ENUM.inspect_player_idle(player) or force then
				change_player_state(player, ENUM.PLAYER_STATE_TYPE.PLAYER_STATE_PVP, param)
				return true
			else
				return false
			end
		end,
		-- 角色加入排位
		[ENUM.PLAYER_STATE_TYPE.PLAYER_STATE_QUALIFYING] = function(player, param, force)
			if ENUM.inspect_player_idle(player) or force then
				change_player_state(player, ENUM.PLAYER_STATE_TYPE.PLAYER_STATE_QUALIFYING, param)
				return true
			else
				return false
			end
		end,
	}
	local fn = switch[state]
	if fn ~= nil then
		return fn(player, param, force)
	else
		return false
	end
end

-- 角色状态变化通知（服务通知角色离开指定场景）
function COMMAND:on_leave_environment(state)
	local player = self.user:get("Player")
	if player.state == state then
		local param = player.scene
		change_player_state(player, ENUM.PLAYER_STATE_TYPE.PLAYER_STATE_IDLE)
		return param
	else
		return nil
	end
end

-- '请求/命令' - 注册
HANDLER.REQUEST = REQUEST
HANDLER.CMD     = COMMAND
return HANDLER
