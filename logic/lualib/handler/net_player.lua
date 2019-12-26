-----------------------------------------------------------
--- 测试命令
-----------------------------------------------------------
local skynet  	= require "skynet"


local HANDLER		= {}
local REQUEST 		= {}
local COMMAND      	= {}

-----------------------------------------------------------
--- 内部变量/内部逻辑
-----------------------------------------------------------

-----------------------------------------------------------
--- 网络请求接口
-----------------------------------------------------------

function REQUEST:player_info()
	self.response("player_info_resp")
end

-----------------------------------------------------------
--- 内部命令
-----------------------------------------------------------

-- 结算
function COMMAND:player_settle(win, channel, double)
	-- 底分
	local baseMoney = 100
	local type = channel % 10
	if type == 2 then
		baseMoney = baseMoney * 3
	elseif type == 3 then
		baseMoney = baseMoney * 5
	elseif type == 4 then
		baseMoney = baseMoney * 10
	end

	local money = baseMoney * double

	if win then
		self.user:call("Player", "add_resource", money)
	else
		self.user:call("Player", "del_resource", money)
	end
end

HANDLER.REQUEST = REQUEST
HANDLER.COMMAND	= COMMAND
return HANDLER
