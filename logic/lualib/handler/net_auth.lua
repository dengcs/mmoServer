-----------------------------------------------------------
--- 游戏服登录逻辑
-----------------------------------------------------------
local skynet  	= require "skynet"
local player	= require "db.mongo.player"
local allocid	= require "utils.allocid"


local HANDLER		= {}
local REQUEST 		= {}

-----------------------------------------------------------
--- 内部变量/内部逻辑
-----------------------------------------------------------

local login_acount 	= nil
local player_id 	= nil

-----------------------------------------------------------
--- 网络请求接口
-----------------------------------------------------------
-- 请求选角状态
function REQUEST:disconnect()
	skynet.send(skynet.self(), "lua", "disconnect")
end

-- 请求选角状态
function REQUEST:query_players()
	local resp = "query_players_resp"
	local ret = 1
	
	local account = self.proto.account
	local data = player.keys({account = account})
	
	if data and next(data) then
		ret = 0
		player_id = data[1].pid
	end
	
	login_acount = account
	
	local ret_msg = {ret = ret}
	self.response(resp, ret_msg)
end

-- 请求创建角色
function REQUEST:create_player()
	local resp = "create_player_resp"
	local ret = 1
	
	if login_acount then

		local vdata = {
			pid			= allocid.generate(),
			sex 		= self.proto.sex,
			nickname  	= self.proto.nickname,
			portrait  	= self.proto.portrait,
			account   	= login_acount,
		}
		
		local result = player.insert(vdata)
		
		if result and result.n == 1 then
			player_id = vdata.pid
	    	ret = 0
		end
	end
    
    local ret_msg = {ret = ret}
    self.response(resp, ret_msg)
end

-- 登录
function REQUEST:player_login()
	local resp = "player_login_resp"
	local ret = 1
	
	if player_id then
	    local ok = skynet.call(GLOBAL.SERVICE_NAME.USERCENTERD, "lua", "load", player_id)
	    if ok == 0 then
	    	ret = 0
	    	self.user:call("Player", "on_login", player_id)
	    end
	end
    
    local ret_msg = {ret = ret}
    self.response(resp, ret_msg)
end

HANDLER.REQUEST   	= REQUEST
return HANDLER
