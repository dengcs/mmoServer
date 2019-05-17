-----------------------------------------------------------
--- 测试命令
-----------------------------------------------------------
local skynet  	= require "skynet"


local HANDLER		= {}
local REQUEST 		= {}

-----------------------------------------------------------
--- 内部变量/内部逻辑
-----------------------------------------------------------

-----------------------------------------------------------
--- 网络请求接口
-----------------------------------------------------------

function REQUEST:cmd_test()
	local cmd_str = self.proto.cmd_str

	local params = cmd_str:split(" ")
	local cmd = table.remove(params, 1)

	local handler = {}

	function handler.test(p1, p2)
		print("p1", p1, "p2", p2)
	end

	local fn = handler[cmd]
	if IS_FUNCTION(fn) then
		fn(table.unpack(params))
	end

	self.response("cmd_test_resp")
end

HANDLER.REQUEST   	= REQUEST
return HANDLER
