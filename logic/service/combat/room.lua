--
-- 房间赛组队服务
--
local service = require "service_factory.service"
local skynet  = require "skynet"
local model = require "combat.model"
local utils = require "combat.utils"
local ENUM    = require "gameenum"
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
          stage    = place.member.stage,
          skin     = place.member.skin,
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

-- 构造队伍简单快照
-- 1. 频道编号
-- 2. 队伍信息
local function simple(cid, team)
  local snapshot = 
  {
    channel = cid,
    roomid  = team.id,
    state   = team.state,
    mcount  = team:size(),
    number  = team:capacity(),
  }
  return snapshot
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
        return ERRCODE.ROOM_UNKNOWN_CHANNEL
    end
    
    -- 创建房间
    local team = channel:create(vdata)
    
    if team ~= nil then
        -- 频道广播
        channel:broadcast("room_append_notify", {v = simple(cid, team)})
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
        return ERRCODE.ROOM_UNKNOWN_CHANNEL
    end
    
    -- 队伍检查
    local team = channel:get(tid)
    if team == nil then
        return ERRCODE.ROOM_NOT_EXISTS
    end
    if not team:prepare() then
        return ERRCODE.ROOM_NOT_PERPARE
    end
    
    -- 加入队伍
    local member = team:join(vdata)
    if member ~= nil then
        -- 频道广播
        channel:broadcast("room_modify_notify", {v = simple(cid, team)})
        return 0
    else
        return ERRCODE.ROOM_JOIN_FAILED
    end
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
  -- 获取频道
  local channel = channels[cid]
  if channel == nil then
    return ERRCODE.ROOM_UNKNOWN_CHANNEL
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
      return ERRCODE.ROOM_UNKNOWN_CHANNEL
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

-- 查找房间
-- 1. 房间编号
-- 2. 角色编号
function COMMAND.on_seek(tid, uid)
	for cid, channel in pairs(channels) do
    local team = channel:get(tid)
    if team ~= nil then
      return simple(cid, team)
    end
  end
  return nil
end

-- "准备/开始"
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色编号
function COMMAND.on_start(cid, tid, uid)
    -- 获取频道
    local channel = channels[cid]
    if channel == nil then
      return ERRCODE.ROOM_UNKNOWN_CHANNEL
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
    -- 准备就绪
    if member.uid ~= team.owner then
      member:convert("READY")
      team:synchronize(cid)
      return 0
    else
      local count = 0
      for _, v in pairs(team.members) do
        if (v.uid ~= team.owner) and (not v:ready()) then
          return ERRCODE.ROOM_WRONG_STATE
        else
          count = count + 1
        end
      end
      ---------------------------------------------------
      --- 开启战场
      ---------------------------------------------------
      
      local users = {}
      for k, v in pairs(team.members) do
        -- 保存成员快照
        local user = v:snapshot()
        table.insert(users, user)
      end
    
      local gameid = utils.start(users)
      if not gameid then
        -- 战场启动失败（强制恢复成员状态）
        return ERRCODE.ROOM_START_FAILED
      else
          team:convert("RUNNING")
          for _, v in pairs(team.members) do
            v:convert("RUNNING")
          end
          -- 频道广播
          channel:broadcast("room_modify_notify", {v = simple(cid, team)})
          return 0
      end
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
    return ERRCODE.ROOM_UNKNOWN_CHANNEL
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

-- 赛后返回
-- 1. 频道编号
-- 2. 队伍编号
-- 3. 角色编号
function COMMAND.on_return(cid, tid, uid)
	-- 获取频道
  local channel = channels[cid]
  if channel == nil then
    return ERRCODE.ROOM_UNKNOWN_CHANNEL
  end
  -- 队伍检查
  local team = channel:get(tid)
  if team == nil then
    return ERRCODE.ROOM_NOT_EXISTS
  end
  if not team:prepare() then
    return ERRCODE.ROOM_NOT_PREPARE
  end
  -- 成员检查
  local member = team:get(uid)
  if member == nil then
    return ERRCODE.ROOM_NOT_MEMBER
  end
  -- 状态转换
  member:convert("PREPARE")
  team:synchronize(cid, "revert")
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
    local cid = assert(vdata.cid)
    local tid = assert(vdata.tid)
    -- 获取频道
    local channel = channels[cid]
    if channel == nil then
      return ERRCODE.ROOM_UNKNOWN_CHANNEL
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
      channel:broadcast("room_modify_notify", {v = simple(cid, team), m = team.minor})
      return 0
    end
end

-----------------------------------------------------------
--- 注册房间组队服务
-----------------------------------------------------------
service.register({
	CMD     = COMMAND,
})