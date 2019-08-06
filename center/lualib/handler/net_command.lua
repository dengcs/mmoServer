-----------------------------------------------------------
--- 测试命令
-----------------------------------------------------------
local skynet  	= require "skynet"
local mail		= require "utils.mail"


local HANDLER		= {}
local REQUEST 		= {}

-----------------------------------------------------------
--- 内部变量/内部逻辑
-----------------------------------------------------------

-----------------------------------------------------------
--- 网络请求接口
-----------------------------------------------------------

function REQUEST:game_cmd_test()
	local cmd_str = self.proto.cmd_str

	local params = cmd_str:split(" ")
	local cmd = table.remove(params, 1)

	local handler = {}

	function handler.test(p1, p2)
		print("p1", p1, "p2", p2)
	end

	function handler.load_mail()
		local pid 	= self.user.pid
		local ok, mails = skynet.call(GLOBAL.SERVICE_NAME.MAIL, "lua", "load", pid)
		print("mails--", table.tostring(mails))
	end

	function handler.text_mail()
		local pid 		= self.user.pid
		local title		= "邮件标题"
		local content	= "邮件内容"
		mail.deliver_mail(pid, title, content)
	end

	function handler.send_msg(name, pid)
		local payload = { receive_pid = pid, channel = 2, content = "测试发送" }

		local message = {
			header = {
				proto 	= name,
			},
			payload = payload
		}

		local byte_fd 	= string.pack(">J", 1)
		local msg_data 	= skynet.packstring(message)

		local compose_data = {byte_fd, msg_data}
		skynet.rawsend(skynet.self(), "client", table.concat(compose_data))
	end

	local fn = handler[cmd]
	if IS_FUNCTION(fn) then
		fn(table.unpack(params))
	end

	self.response("game_cmd_test_resp")
end

HANDLER.REQUEST   	= REQUEST
return HANDLER
