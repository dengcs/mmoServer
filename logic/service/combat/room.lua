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

-- 队伍同步通知
-- 1. 频道编号
-- 2. 返回标志
function Team:synchronize(channel, revert)
  -- 座位快照构造逻辑
  -- 1. 座位信息
  local function snapshot(place)
    local snapshot  = {}
    snapshot.id     = place.id
    snapshot.locked = place.locked and 1 or 0
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
      -- 修正状态
      if place.member:prepare() then
        snapshot.member.state = 5
      end
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

-- 构造队伍简单快照
-- 1. 频道编号
-- 2. 队伍信息
local function simple(cid, team)
	local snapshot = 
	{
		channel = cid,
		roomid  = team.id,
		passwd  = team.passwd,
		state   = team.state,
		mcount  = team:size(),
		number  = team:capacity(),
	}
	return snapshot
end


-- 配置重载
function COMMAND.on_reload()
end

-- 切换频道
-- 1. 频道编号
-- 2. 角色编号
function COMMAND.on_channel_switch(cid, uid)
	return 0
end

-- 房间同步(由'AGENT'发起)
-- 1. 频道编号
-- 2. 队伍编号
function COMMAND.on_synchronize(cid, tid)
	return 0
end

-- 创建房间（同步由'AGENT'发起）
-- 1. 频道编号
-- 2. 创建者信息
-- 3. 战场主类型
-- 4. 战场子类型
-- 5. 赛道编号
-- 6. 房间密码
function COMMAND.on_create(cid, vdata, major, minor, track, passwd, novice)
    return 0
end

-- 加入房间（同步由'AGENT'发起）
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色信息
-- 4. 房间密码
function COMMAND.on_join(cid, tid, vdata, passwd)
    return 0
end

-- 快速加入（同步由'AGENT'发起）
-- 1. 频道编号
-- 2. 角色信息
-- 3. 战场主类型
-- 4. 战场子类型
function COMMAND.on_qkjoin(cid, vdata, major, minor)
    return 0
end

-- 离开房间（主动发起同步）
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色编号
function COMMAND.on_quit(cid, tid, uid)
	return 0
end

-- 踢掉队友
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色编号
-- 4. 目标编号
function COMMAND.on_kickout(cid, tid, source, target)
	return 0
end

-- 解散房间（gm操作）
-- 1. 频道编号
-- 2. 房间编号
function COMMAND.on_dismiss(cid, tid)
	return 0
end

-- 更换座位
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色编号
-- 4. 座位编号
function COMMAND.on_transplace(cid, tid, uid, pos)
    return 0
end

-- 锁定座位
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色编号
-- 4. 座位编号
function COMMAND.on_locked(cid, tid, uid, pos)
	return 0
end

-- 解锁座位
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色编号
-- 4. 座位编号
function COMMAND.on_unlock(cid, tid, uid, pos)
	return 0
end

-- 改变"比赛/赛道"类型
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色编号
-- 4. 战场类型
-- 5. 赛道类型
function COMMAND.on_change(cid, tid, uid, minor, track)
	return 0
end

-- 改变装备
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色编号
-- 4. 赛车信息
-- 5. 副驾信息
function COMMAND.on_change_equipment(cid, tid, uid, car, copilot)
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

-- 修改密码
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色编号
-- 4. 房间密码
function COMMAND.on_change_passwd(cid, tid, uid, passwd)
	return 0
end

-- 改变编组
-- 1. 频道编号
-- 2. 房间编号
-- 3. 角色编号
function COMMAND.on_change_team(cid, tid, uid)
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
-- 2. 房间编号
-- 3. 聊天协议
-- 4. 聊天内容
function COMMAND.on_chat(tid, name, data)
    return 0
end

-- 查找房间（需返回房间简单信息）
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

-- 赛后返回（前端通知赛后返回房间面板）
-- 1. 频道编号
-- 2. 队伍编号
-- 3. 角色编号
-- 4. 角色等级（等级更新）
function COMMAND.on_return(cid, tid, uid, ulevel)
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
