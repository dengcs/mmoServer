-----------------------------------------------------------
--- 游戏服登录逻辑
-----------------------------------------------------------
local skynet     = require "skynet_ex"
local userdriver = skynet.userdriver()


local HANDLER    = {}
local REQUEST = {}

-----------------------------------------------------------
--- 内部变量/内部逻辑
-----------------------------------------------------------
local dbname  = "test"
local tblname = "player_tbl"

local login_acount = nil
local player_uid = nil
-----------------------------------------------------------
--- 网络请求接口
-----------------------------------------------------------

-- 请求选角状态
function REQUEST:query_players()
	local resp = "query_players_resp"
	local ret = 1
	
	local account = self.proto.account
	local sql = string.format("SELECT uid FROM %s WHERE account = '%s'", tblname, account)
	local result = userdriver.db_select(dbname, sql)
	
	if result then
		ret = 0
		login_acount = account
		player_uid = 10000001
	end
	
	local ret_msg = {ret = ret}
	self.response(resp, ret_msg)
end

-- 请求创建角色
function REQUEST:create_player()
	local resp = "create_player_resp"
	local ret = 1
	
	if login_acount then
		local sex 		= self.proto.sex
		local nickname  = self.proto.nickname
		local portrait  = self.proto.portrait
		
		local sql = string.format("INSERT %s(sex, nickname, portrait) VALUES(%s,'%s','%s')", tblname, sex, nickname, portrait)
		local result = userdriver.db_insert(dbname, sql)
		
		if result then
			ret = 0
			player_uid = 10000001
		end
	end
    
    local ret_msg = {ret = ret}
    self.response(resp, ret_msg)
end

-- 登录
function REQUEST:player_login()
	local resp = "player_login_resp"
	local ret = 1
	
	if player_uid then
		skynet.error("dcs---create_player")
	    skynet.call(GLOBAL.SERVICE_NAME.USERCENTERD, "lua", "load", player_uid)
	    skynet.error("dcs---data--"..table.tostring(self.user))
	end
    
    local ret_msg = {ret = ret}
    self.response(resp, ret_msg)
end

HANDLER.REQUEST   = REQUEST
return HANDLER