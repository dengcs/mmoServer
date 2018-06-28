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

-- 加入房间
function REQUEST:room_join()
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

-- 转交队伍
function REQUEST:room_change_owner()
	return 0
end


-- 邀请好友
function REQUEST:room_invite()
	return 0
end

-- 查找房间
function REQUEST:room_seek()
	return 0
end

-- 准备/开始
function REQUEST:room_start()
	return 0
end

-- 取消准备
function REQUEST:room_stop()
	return 0
end

-- 返回房间（前端调用，恢复成员状态）
function REQUEST:room_return()
	return 0
end

-- '请求/命令' - 注册
handler.REQUEST = REQUEST
handler.CMD     = COMMAND
return handler
