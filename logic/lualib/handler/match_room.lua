--
-- 房间战组队
--
local skynet  = require "skynet"
local handler = {}
local REQUEST = {}
local COMMAND = {}

-----------------------------------------------------------
-- 请求服务接口
-----------------------------------------------------------


-- 创建房间
function REQUEST:room_create()
	return 0
end

-- 快速加入
function REQUEST:room_qkjoin()
	return 0
end

-- 离开房间
function REQUEST:room_quit()
	return 0
end

-- 邀请好友
function REQUEST:room_invite()
	return 0
end

-- '请求/命令' - 注册
handler.REQUEST = REQUEST
handler.CMD     = COMMAND
return handler
