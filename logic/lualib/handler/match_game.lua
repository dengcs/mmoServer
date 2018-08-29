--
-- 赛场服务接口
--
local skynet  = require "skynet"
local ENUM    = require "gameenum"

local handler = {}
local REQUEST = {}
local COMMAND = {}

-----------------------------------------------------------
-- 服务回调接口
-----------------------------------------------------------

-- 赛事结算通知（对战个人结算接口）
-- 1. 赛事结果
-- 2. 离队标志
function COMMAND:on_game_complete(vdata, quit)
	return 0
end


-----------------------------------------------------------
-- 网络请求接口
-----------------------------------------------------------


-- 比赛数据更新（无返回）
function REQUEST:game_update()
	local player  = self.user:get("Player")
	if ENUM.inspect_player_game(player) then
		local uid     = player.uid
		local alias   = player.scene
		skynet.send(alias, "lua", "on_game_update", uid, self.proto.data)
	end
	return 0
end

-- 参赛者离线通知（强制离开比赛）
function REQUEST:game_leave()
	local player  = self.user:get("Player")
	if ENUM.inspect_player_game(player) then
		local uid     = player.uid
		local alias   = player.scene
		skynet.send(alias, "lua", "on_leave", uid)
	end
	
	self.response("game_leave_resp", { ret = 0 })
	return 0
end

-- 参赛者重连请求
function REQUEST:game_reconnect()
	return 0
end

-- '请求/命令' - 注册
handler.REQUEST = REQUEST
handler.CMD     = COMMAND
return handler
