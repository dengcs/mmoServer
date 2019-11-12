-----------------------------------------------------------
--- 游戏服登录逻辑
-----------------------------------------------------------
local skynet  	= require "skynet"
local db_player	= require "db.mongo.player"
local allocid	= require "utils.allocid"
local cluster	= require "skynet.cluster"


local HANDLER		= {}
local REQUEST 		= {}
local COMMAND 		= {}

-----------------------------------------------------------
--- 内部变量/内部逻辑
-----------------------------------------------------------

local login_acount 	= nil
local player_id 	= nil

-----------------------------------------------------------
--- 网络请求接口
-----------------------------------------------------------

-- 请求选角状态
function REQUEST:query_players()
	local resp = "query_players_resp"
	local ret = 1
	
	local account = self.proto.account
	local data = db_player.keys({account = account})
	
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

		local vData = {
			pid			= allocid.generate(),
			sex 		= self.proto.sex,
			nickname  	= self.proto.nickname,
			portrait  	= self.proto.portrait,
			account   	= login_acount,
			level		= 1,
		}
		
		local result = db_player.insert(vData)

		if result then
			player_id = vData.pid
			this.call("player_create", player_id)
			ret = 0
		end
	end
    
    local ret_msg = {ret = ret}
    self.response(resp, ret_msg)
end

-- 登录
function REQUEST:player_login()
	local resp = "player_login_resp"
	local msg_data = {ret = 1}

	if player_id then
	    local ok = skynet.call(GLOBAL.SERVICE_NAME.USERCENTER, "lua", "load", player_id)
	    if ok == 0 then
			this.call("player_login", player_id)
			msg_data.ret = 0
			msg_data.pid = player_id
		end
	end
    
    self.response(resp, msg_data)
end

-----------------------------------------------------------
--- 内部命令
-----------------------------------------------------------

function COMMAND:player_create(pid)
	self.user:call("Player", "on_create")
	cluster.call("center", GLOBAL.SERVICE_NAME.SOCIAL, "load", pid)
end

function COMMAND:player_login(pid)
	self.user:call("Player", "on_login", pid)
	local snapshot = self.user:call("Player", "get_snapshot")
	cluster.call("center", GLOBAL.SERVICE_NAME.SOCIAL, "update", pid, snapshot)
	cluster.call("center", GLOBAL.SERVICE_NAME.USERCENTER, "set_fd", pid, self.client_fd)
end

HANDLER.REQUEST   	= REQUEST
HANDLER.COMMAND   	= COMMAND
return HANDLER
