local ENUM = {}

-----------------------------------------------------------
-- 角色状态枚举
-----------------------------------------------------------
local PLAYER_STATE_TYPE =
{
	PLAYER_STATE_IDLE		= 1,			-- 空闲状态（主场景下）
	PLAYER_STATE_ROOM		= 2,			-- 房间组队
	PLAYER_STATE_PVP		= 3,			-- PVP组队
	PLAYER_STATE_QUALIFYING = 4,			-- 排位组队
	PLAYER_STATE_GAME		= 5,			-- 正在比赛
	PLAYER_STATE_ACTIVITY	= 6,			-- 限时活动
	PLAYER_STATE_FACTION    = 7,			-- 车队组队
}
ENUM.PLAYER_STATE_TYPE = PLAYER_STATE_TYPE

-- 检查角色是否空闲状态
function ENUM.inspect_player_idle(player)
	if player.state == PLAYER_STATE_TYPE.PLAYER_STATE_IDLE then
		return true
	else
		return false
	end
end

-- 检查角色是否房间组队状态
function ENUM.inspect_player_room(player)
	if player.state == PLAYER_STATE_TYPE.PLAYER_STATE_ROOM then
		return true
	else
		return false
	end
end

-- 检查角色是否对战组队状态
function ENUM.inspect_player_pvp(player)
	if player.state == PLAYER_STATE_TYPE.PLAYER_STATE_PVP then
		return true
	else
		return false
	end
end

-- 检查角色是否排位组队状态
function ENUM.inspect_player_qualifying(player)
	if player.state == PLAYER_STATE_TYPE.PLAYER_STATE_QUALIFYING then
		return true
	else
		return false
	end
end

-- 检查角色是否比赛状态
function ENUM.inspect_player_game(player)
	if player.state == PLAYER_STATE_TYPE.PLAYER_STATE_GAME then
		return true
	else
		return false
	end
end

-- 检查角色是否限时活动
function ENUM.inspect_player_activity(player)
	if player.state == PLAYER_STATE_TYPE.PLAYER_STATE_ACTIVITY then
		return true
	else
		return false
	end
end

-- 检查角色是否车队组队状态
function ENUM.inspect_player_faction(player)
	if player.state == PLAYER_STATE_TYPE.PLAYER_STATE_FACTION then
		return true
	else
		return false
	end
end

-- 按别名获取对应角色状态值
function ENUM.get_pstate_type(alias)
	local switch =
	{
		IDLE       = PLAYER_STATE_TYPE.PLAYER_STATE_IDEL,
		ROOM       = PLAYER_STATE_TYPE.PLAYER_STATE_ROOM,
		PVP        = PLAYER_STATE_TYPE.PLAYER_STATE_PVP,
		QUALIFYING = PLAYER_STATE_TYPE.PLAYER_STATE_QUALIFYING,
		GAME       = PLAYER_STATE_TYPE.PLAYER_STATE_GAME,
		ACTIVITY   = PLAYER_STATE_TYPE.PLAYER_STATE_ACTIVITY,
		FACTION    = PLAYER_STATE_TYPE.PLAYER_STATE_FACTION,
	}
	local retval = switch[alias]
	if retval ~= 0 then
		return retval
	else
		error(string.format("enum.get_pstate_type(%s) : illegal alias", alias))
	end
end

function ENUM.get(name, key)
	return ENUM[name][key]
end

return ENUM
