--
-- 组队比赛公共部分代码
--
local skynet  = require "skynet"
local ENUM    = require "config.enum"
local HANDLER = {}
local REQUEST = {}
local COMMAND = {}

local PLAYER_STATE_TYPE = ENUM.PLAYER_STATE_TYPE


-----------------------------------------------------------
--- 服务公共回调
-----------------------------------------------------------

-- 变更角色状态
local function change_user_state(user, state, param)
	-- 变更角色状态
	user.state = state
	user.param = param
end

-- 角色状态变化通知（服务通知角色角色进入指定场景）
-- 1. 场景状态（角色进入场景后的新状态）
-- 2. 场景参赛（队伍编号或战场编号）
-- 3. 强制标志
function COMMAND:on_enter_environment(state, param)
	local user = self.user
	local switch =
	{
		-- 角色加入战场
		[PLAYER_STATE_TYPE.PLAYER_STATE_GAME] = function(user, param)
			if ENUM.inspect_player_idle(user) then
				change_user_state(user, PLAYER_STATE_TYPE.PLAYER_STATE_GAME, param)
				return true
			else
				return false
			end
		end,
	}
	local fn = switch[state]
	if fn then
		return fn(user, param)
	end
	return false
end

-- 角色状态变化通知（服务通知角色离开指定场景）
function COMMAND:on_leave_environment(state)
	local user = self.user
	if user.state == state then
		change_user_state(user, PLAYER_STATE_TYPE.PLAYER_STATE_IDLE)
		return true
	end
	return false
end

-- '请求/命令' - 注册
HANDLER.REQUEST = REQUEST
HANDLER.COMMAND = COMMAND
return HANDLER
