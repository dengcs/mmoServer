-----------------------------------------------------------
--- 游戏服登录逻辑
-----------------------------------------------------------
local skynet     = require "skynet_ex"
local json    = require "cjson"
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
	
	if next(result) then
		ret = 0
		player_uid = result[1].uid
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
			sex 		= self.proto.sex,
			nickname  = self.proto.nickname,
			portrait  = self.proto.portrait,
		}
		
		local sql = string.format("INSERT %s(account,vdata) VALUES('%s','%s')", tblname, login_acount, json.encode(vdata))
		local result = userdriver.db_insert(dbname, sql)
		
		if result then
			player_uid = result.insert_id		
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
	
	if player_uid then
	    local ok = skynet.call(GLOBAL.SERVICE_NAME.USERCENTERD, "lua", "load", player_uid)
	    if ok == 0 then
	    	ret = 0
	    	self.user:call("Player", "on_login", player_uid)
	    end
	    skynet.error("dcs---data--"..table.tostring(self.user))
	end
    
    local ret_msg = {ret = ret}
    self.response(resp, ret_msg)
end

HANDLER.REQUEST   = REQUEST
return HANDLER
