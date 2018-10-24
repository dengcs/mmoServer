--
-- 房间赛组队服务
--
local skynet  = require "skynet"
local service = require "service_factory.service"
local model = require "combat.model"
local utils = require "combat.utils"
local robot = require "combat.robot"
local ENUM    = require "config.gameenum"
-- 底层驱动加载
local userdriver = require "driver.userdriver"

local COMMAND = {}

-----------------------------------------------------------
--- 房间赛队伍模型
-----------------------------------------------------------

-- 加载队伍模型
local Team = model.Team

-- 队伍同步通知
-- 1. 频道编号
-- 2. 返回标志
function Team:synchronize(channel, revert)
	-- 座位快照构造逻辑
	-- 1. 座位信息
	local function snapshot(place)
		local snapshot  = {}
		snapshot.id     = place.id
		if place.member ~= nil then
			snapshot.member =
			{
				player =
				{
					uid      = place.member.uid,
					nickname = place.member.nickname,
					ulevel   = place.member.ulevel,
					vlevel   = place.member.vlevel,
					score    = place.member.score,
				},
				teamid  = place.member.teamid,
				state   = place.member.state,
			}
		end
		return snapshot
	end
	-- 房间同步逻辑
	local name = "room_synchronize_notify"
	local data = {}
	data.channel = channel
	data.roomid  = self.id
	data.owner   = self.owner
	data.state   = self.state
	data.places  = {}
	for _, place in pairs(self.places) do
		table.insert(data.places, snapshot(place))
	end
	if not revert then
		self:broadcast(name, { v = data })
	else
		for _, v in pairs(self.members) do
			if not v:running() then
				v:notify(name, { v = data })
			end
		end
	end
end
-----------------------------------------------------------
--- 房间赛频道模型
-----------------------------------------------------------
local Channel = {}
Channel.__index = Channel

-- 构建频道
function Channel.new()
	local channel = {}
	-- 注册成员方法
	setmetatable(channel, Channel)
	
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

---- 消息广播
--function Channel:broadcast(name, data)
--	for k, v in pairs(self.onlines) do
--		userdriver.usersend(k, "on_common_notify", name, data)
--	end
--end

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
	local errcode, retval = userdriver.usercall(uid, "on_enter_environment", ENUM.PLAYER_STATE_TYPE.PLAYER_STATE_ROOM, {cid = cid, tid = tid}, force)
	if not retval then
		errcode = (errcode ~= 0 and errcode) or ERRCODE.ROOM_ENTERENV_FAILED
	end
	return errcode
end

-- 离开组队服务
-- 1. 角色编号
-- 2. 频道编号
-- 3. 队伍编号
local function leave_environment(uid, cid, tid)
	local errcode, retval = userdriver.usercall(uid, "on_leave_environment", ENUM.PLAYER_STATE_TYPE.PLAYER_STATE_ROOM, {cid = cid, tid = tid})
	if not retval then
		errcode = (errcode ~= 0 and errcode) or ERRCODE.ROOM_LEAVEENV_FAILED
	end
	return errcode
end

-- 间隔时间
local function interval()
	return 100
end

local function schedule()
	-- 逻辑
	local function fn()
		for id, channel in pairs(channels) do
			for _, team in pairs(channel.teams) do
				if team:prepare() then
					if team:full() then
						team:start()
						utils.start(1,1,team:snapshot())
					else
						local member = robot.generate_robot()
						team:join(member)
					end
				end
			end
		end
	end
	-- 异常处理
	local function catch(message)
		LOG_ERROR(message)
	end
	-- 任务处理
	xpcall(fn, catch)
	skynet.timeout(interval(), schedule)
end

-----------------------------------------------------------
--- 房间组队服务接口
-----------------------------------------------------------

-- 创建房间
-- 1. 频道编号
-- 2. 创建者信息
function COMMAND.on_create(cid, vdata)
    -- 获取频道
    local channel = channels[cid]
	if channel == nil then
		return ERRCODE.COMMON_PARAMS_ERROR
	end

    -- 创建房间
    local team = channel:create(vdata)
    if team ~= nil then
        return 0
    else
        return ERRCODE.ROOM_CREATE_FAILED
    end
end

-- 加入房间
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色信息
function COMMAND.on_join(cid, tid, vdata)
    -- 获取频道
    local channel = channels[cid]
    if channel == nil then
        return ERRCODE.COMMON_PARAMS_ERROR
    end
    
    -- 队伍检查
    local team = channel:get(tid)
    if team == nil then
        return ERRCODE.COMMON_CLIENT_ERROR
    end
    if not team:prepare() then
        return ERRCODE.COMMON_CLIENT_ERROR
    end
    
    -- 加入队伍
    local member = team:join(vdata)
    if member ~= nil then
        return 0
    else
        return ERRCODE.COMMON_SYSTEM_ERROR
    end
end

-- 邀请好友
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色编号
-- 4. 目标编号
function COMMAND.on_invite(cid, tid, source, target)
	-- 获取频道
	local channel = channels[cid]
	if channel == nil then
		return ERRCODE.COMMON_PARAMS_ERROR
	end
	-- 队伍检查
	local team = channel:get(tid)
	if team == nil then
		return ERRCODE.ROOM_NOT_EXISTS
	end
	if not team:prepare() then
		return ERRCODE.ROOM_NOT_PERPARE
	end
	-- 成员检查
	local member = team:get(source)
	if member == nil then
		return ERRCODE.ROOM_PERMISSION_DINIED
	end
	-- 发出邀请
	local name = "room_invite_notify"
	local data =
	{
		channel  = cid,
		roomid   = team.id,
		uid      = member.uid,
		nickname = member.nickname,
	}
	userdriver.usersend(target, "on_common_invite", name, data)
	return 0
end

-- 队伍聊天（聊天服务转发）
-- 1. 频道编号
-- 2. 聊天协议
-- 3. 聊天内容
function COMMAND.on_chat(cid, tid, name, data)
    -- 获取频道
    local channel = channels[cid]
    if channel == nil then
		return ERRCODE.COMMON_PARAMS_ERROR
    end
    -- 队伍检查
    local team = channel:get(tid)
    if team ~= nil then
		-- 消息转发
		team:broadcast(name, data)
		return 0
    else
		return ERRCODE.ROOM_NOT_EXISTS
    end
end

-- 取消准备
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色编号
function COMMAND.on_stop(cid, tid, uid)
	-- 获取频道
	local channel = channels[cid]
	if channel == nil then
		return ERRCODE.COMMON_PARAMS_ERROR
	end
	-- 队伍检查
	local team = channel:get(tid)
	if team == nil then
		return ERRCODE.ROOM_NOT_EXISTS
	end
	if not team:prepare() then
		return ERRCODE.ROOM_NOT_PERPARE
	end
	-- 成员检查
	local member = team:get(uid)
	if member == nil then
		return ERRCODE.ROOM_PERMISSION_DINIED
	end
	-- 状态转换
	member:convert("PREPARE")
	team:synchronize(cid)
	return 0
end

-- 战场通知战斗结束
-- 1. 队伍信息
-- 2. 胜者编号
function COMMAND.on_game_finish(vdata, uid)
    local cid = assert(vdata.cid)
    local tid = assert(vdata.tid)
    -- 获取频道
    local channel = channels[cid]
    if channel == nil then
      return ERRCODE.COMMON_PARAMS_ERROR
    end
    -- 队伍检查
    local team = channel:get(tid)
    if team == nil then
      return ERRCODE.ROOM_NOT_EXISTS
    else
      -- 更换领队
      local member = team:get(uid)
      if member then
        if team.owner ~= member.uid then
          team.owner = member.uid
        end
      end
      -- 变更状态
      team:convert("PREPARE")
      team:synchronize(cid)
      return 0
    end
end

-----------------------------------------------------------
--- 注册房间组队服务
-----------------------------------------------------------

local handler = {}

function handler.init_handler()
	skynet.timeout(interval(), schedule)
end

-- 消息分发逻辑
-- 1. 消息来源
-- 2. 消息类型
-- 3. 消息内容
function handler.command_handler(source, cmd, ...)
	local fn = COMMAND[cmd]
	if fn then
		return fn(...)
	else
		ERROR("svcmanager : command[%s] can't find!!!", cmd)
	end
end

service.start(handler)
