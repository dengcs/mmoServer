--
-- 房间赛组队服务
--
local service = require "service_factory.service"
local skynet  = require "skynet"
local model = require "combat.model"
-- 底层驱动加载
local userdriver = require "driver.userdriver"

local COMMAND = {}

-----------------------------------------------------------
--- 房间赛队伍模型
-----------------------------------------------------------

-- 加载队伍模型
local Team = model.Team

-----------------------------------------------------------
--- 房间赛频道模型
-----------------------------------------------------------
local Channel = {}
Channel.__index = Channel

-- 构建频道
function Channel.new()
	local channel = {}
	-- 注册成员方法
	for k, v in pairs(Channel) do
		channel[k] = v
	end
	-- 设置频道数据
	channel.onlines = {}	-- 在线角色列表（不包括房间内角色）
	channel.teams   = {}	-- 频道房间列表
	return channel
end

-- 加入频道
function Channel:join(uid)
	self.onlines[uid] = 0
end

-- 离开频道
function Channel:quit(uid)
	self.onlines[uid] = nil
end

-- 消息广播
function Channel:broadcast(name, data)
	for k, v in pairs(self.onlines) do
		userdriver.usersend(k, "on_common_notify", name, data)
	end
end

-- 获取队伍
function Channel:get(tid)
	return self.teams[tid]
end

-- 创建队伍
function Channel:create(vdata)
	local team = Team.new(vdata)
	if team ~= nil then
		self.teams[team.id] = team
	end
	return team
end

-- 移除队伍
function Channel:remove(tid)
	local team = self.teams[tid]
	if team ~= nil then
		self.teams[tid] = nil
	end
	return team
end

-----------------------------------------------------------
--- 内部变量/内部逻辑
-----------------------------------------------------------

-- 频道集合
local channels = 
{
	[1] = Channel.new(),	-- 自由频道
	[2] = Channel.new(),	-- 初级频道
	[3] = Channel.new(),	-- 中级频道
	[4] = Channel.new(),	-- 高级频道
}

-- 加入组队服务
-- 1. 角色编号
-- 2. 频道编号
-- 3. 队伍编号
-- 3. 强制标志
local function enter_environment(uid, cid, tid, force)
	return 0
end

-- 离开组队服务
-- 1. 角色编号
-- 2. 频道编号
-- 3. 队伍编号
local function leave_environment(uid, cid, tid)
	return 0
end

-----------------------------------------------------------
--- 房间组队服务接口
-----------------------------------------------------------

-- 创建房间
-- 1. 频道编号
-- 2. 创建者信息
function COMMAND.on_create(cid, vdata)
    return 0
end

-- 加入房间
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色信息
function COMMAND.on_join(cid, tid, vdata)
    return 0
end

-- 转交队长
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色编号
-- 4. 目标编号
function COMMAND.on_change_owner(cid, tid, source, target)
	return 0
end

-- 邀请好友
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色编号
-- 4. 目标编号
function COMMAND.on_invite(cid, tid, source, target)
	return 0
end

-- 队伍聊天（聊天服务转发）
-- 1. 频道编号
-- 2. 聊天协议
-- 3. 聊天内容
function COMMAND.on_chat(tid, name, data)
    return 0
end

-- 查找房间
-- 1. 房间编号
-- 2. 角色编号
function COMMAND.on_seek(tid, uid)
	return 0
end

-- "准备/开始"
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色编号
function COMMAND.on_start(cid, tid, uid)
    return 0
end

-- 取消准备
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色编号
function COMMAND.on_stop(cid, tid, uid)
	return 0
end

-- 赛后返回
-- 1. 频道编号
-- 2. 队伍编号
-- 3. 角色编号
function COMMAND.on_return(cid, tid, uid)
	return 0
end

-- 战场通知角色退出
-- 1. 队伍信息
-- 2. 角色编号
function COMMAND.on_game_leave(vdata, uid)
	return 0
end

-- 战场通知角色返回
-- 1. 队伍信息
-- 2. 角色编号
function COMMAND.on_game_return(vdata, uid)
	
	return 0
end

-- 战场通知战斗结束
-- 1. 队伍信息
-- 2. 胜者编号
function COMMAND.on_game_finish(vdata, uid)
    return 0
end

-----------------------------------------------------------
--- 注册房间组队服务
-----------------------------------------------------------
service.register({
	CMD     = COMMAND,
})
