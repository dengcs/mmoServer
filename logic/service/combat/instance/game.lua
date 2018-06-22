--
-- 对战战场服务
--
local service = require "service_factory.service"
local skynet  = require "skynet"
-- 底层驱动加载
local userdriver = require "driver.userdriver"

local COMMAND = {}
-----------------------------------------------------------
--- 服务常量
-----------------------------------------------------------

-- 服务状态枚举
local ESTATES =
{
	PREPARE		= 1,		-- 赛前准备阶段
	LOADING		= 2,		-- 场景加载阶段
	READY		= 3,		-- 比赛预备阶段
	RUNNING		= 4,		-- 正式比赛阶段
	FINISHED	= 5,		-- 比赛结束阶段
}

-- 赛前准备时间（秒）
local GAME_PREPARE_DURATION = 60

-- 赛道加载时间（秒）
local GAME_LOADING_DURATION = 120

-- 比赛预备时长（秒）
local GAME_READY_DURATION   = 30

-- 默认比赛时长（秒）
local GAME_MATCH_DURATION   = 600

-- 比赛倒数时长（秒）
local GAME_MATCH_COUNTDOWN  = 10

-- 比赛结算时长（秒）
local GAME_FINISH_DURATION  = 150

-----------------------------------------------------------
--- 赛道选择
-----------------------------------------------------------

-----------------------------------------------------------
---  内部逻辑
-----------------------------------------------------------

-- 加入战场服务
local function enter_environment()
	 return 0
end

-- 离开战场服务
local function leave_environment()
	 return 0
end

-----------------------------------------------------------
--- 成员模型
-----------------------------------------------------------
local Member = {}
Member.__index = Member

-- 构造成员对象
-- 1. 参赛者信息
function Member.new(vdata)
	local member = {}
	-- 注册成员方法
	for k, v in pairs(Member) do
		member[k] = v
	end
	-- 设置基础数据
	member.portrait_box_id = vdata.portrait_box_id
	member.teamid     = vdata.teamid		-- 队伍编号
	member.agent      = vdata.agent			-- 角色句柄
	member.uid        = vdata.uid			-- 角色编号
	member.sex        = vdata.sex			-- 角色性别
	member.nickname   = vdata.nickname		-- 角色昵称
	member.portrait   = vdata.portrait		-- 角色头像
	member.ulevel     = vdata.ulevel		-- 角色等级
	member.vlevel     = vdata.vlevel		-- 贵族等级
	member.stage      = vdata.stage			-- 角色段位
	member.state      = 0					-- 角色状态（0 - 准备， 1 - 就绪）
	member.online     = 1					-- 在线状态（1 - 在线， 2 - 离线， 3 - 退出）
	member.skin       = vdata.skin			-- 角色外观
	-- 设置战场数据
	member.game =
	{
		data          = nil,				-- 同步数据
		rank          = 0,					-- 比赛排名
		mark          = 0,					-- 比赛成绩
		point         = 0,					-- 获得积分
		duration      = 0,					-- 完成时间
		addition      = {},					-- 加成信息
		kvdata        = {},					-- 战场统计
	}
	return member
end

-- 战场统计更新
function Member:submit(values)
	for k, v in pairs(values or {}) do
		self.game.kvdata[k] = math.max(v, (self.game.kvdata[k] or 0))
	end
end

-- 战场消息通知
-- 1. 消息名称
-- 2. 消息内容
function Member:notify(name, data)
	-- 过滤掉线成员
	if self.online ~= 1 then
		return
	end
	-- 战场消息通知
	if self.agent ~= nil then
		skynet.send(self.agent, "lua", "on_common_notify", name, data)
	else
		userdriver.usersend(self.uid, "on_common_notify", name, data)
	end
end

-----------------------------------------------------------
--- 战场模型
-----------------------------------------------------------
local Game = {}
Game.__index = Game

-- 构造战场
-- 1. 战场别名
-- 2. 战场主类型
-- 3. 战场子类型
-- 4. 赛道编号
-- 5. 成员列表
-- 6. 附加数据（用于队伍恢复操作）
function Game.new(alias, users)
	local game = {}
	-- 注册成员方法
	for k, v in pairs(Game) do
		game[k] = v
	end
	-- 设置战场数据
	game.alias    = alias				-- 战场名称
	game.state    = ESTATES.PREPARE		-- 战场状态
	game.stime    = 0					-- 开始时间（滴答 = 10毫秒）
	game.etime    = 0					-- 结束时间（滴答 = 10毫秒）
	game.members  = {}					-- 成员列表
	for _, user in pairs(users) do		
		-- 加入战场
		local member = game:join(Member.new(user))
		if member == nil then
			return nil
		end
	end
	return game
end

-- 关闭战场（延迟关闭）
function Game:close()
	-- 关闭战场通知
	if not self.closed then
		-- 设置关闭标志
		self.closed = true
		-- 移除战场成员
		for _, member in pairs(self.members) do
			self:quit(member.uid)
		end
	end
end

-- 加入战场
function Game:join(member)
	if member ~= nil then
		-- 加入服务
		local errcode = enter_environment()
		if errcode ~= 0 then
			return nil
		end
		table.insert(self.members, member)
	end
	return member
end

-- 离开战场
function Game:quit(uid)
	local member = nil
	for _, v in pairs(self.members) do		
		v.online = 3
		-- 成员离线处理
		if v.uid == uid then
			-- 记录退出成员
			member = v
			leave_environment()
			break
		end
	end
	return member
end

-- 指定成员
function Game:get(uid)
	for _, member in pairs(self.members) do
		if member.uid == uid then
			return member
		end
	end
	return nil
end

-- 队伍成员列表
function Game:get_member_list(teamid)
	local list = {}
	for _, member in pairs(self.members) do
		if teamid == member.teamid then
			table.insert(list,member.uid)
		end
	end
	return list
end

-- 判断是否空战场
function Game:empty()
	for _, member in pairs(self.members) do
		if member.online ~= 3 then
			return false
		end
	end
	return true
end

-- 成员掉线
function Game:disconnect(uid)
	local member = nil
	for _, v in pairs(self.members) do
		repeat
			if v.online == 3 then
				break
			end
			if v.uid == uid then
				member   = v
				v.online = 2
			end
		until(true)
	end
	return member
end

-- 成员重连
function Game:reconnect(uid)
	local member = nil
	for _, v in pairs(self.members) do
		if v.online ~= 3 then
			if v.uid == uid then
				member = v
			end
			v.online = 1
		end
	end
	return member
end

-- 消息广播
function Game:broadcast(name, data)
	for _, member in pairs(self.members) do
		member:notify(name, data)
	end
end

-- 构造赛前准备信息
function Game:prepare_snapshot()
	-- 成员快照
	local function snapshot(member)
		local snapshot = {}
		snapshot.teamid   = member.teamid
		snapshot.uid      = member.uid
		snapshot.sex      = member.sex
		snapshot.nickname = member.nickname
		snapshot.portrait = member.portrait
		snapshot.ulevel   = member.ulevel
		snapshot.vlevel   = member.vlevel
		snapshot.portrait_box_id = member.portrait_box_id
		return snapshot
	end
	-- 构造信息
	local data =
	{
		members  = {},
	}
	for _, v in pairs(self.members) do
		table.insert(data.members, snapshot(v))
	end
	return data
end

-- 战斗开始通知（开始赛前准备）
function Game:prepare_start()
	local name = "game_prepare_start"
	local data =
	{
		  data = self:prepare_snapshot(),
	}
	self:broadcast(name, data)
end

-- 赛前状态同步
function Game:prepare_notify()
	local name = "game_prepare_notify"
	local data =
	{
		data = self:prepare_snapshot(),
	}
	self:broadcast(name, data)
end

-- 准备完成通知
function Game:prepare_complete()
	local name = "game_prepare_complete"
	local data =
	{
		data = self:prepare_snapshot(),
	}
	self:broadcast(name, data)
end


-- 创建战场
function COMMAND.on_create(alias)
	return 0
end

-- 关闭战场（通过'game.close'间接调用）
function COMMAND.on_close()
  return 0
end

-- 离开战场（成员强制离开）
-- 1. 角色编号
function COMMAND.on_leave(uid)
	return 0
end

-- 选择'赛车/副驾'
-- 1. 角色编号
function COMMAND.on_change(uid)
	return 0
end

-- 确定赛前准备完成
-- 1. 角色编号
function COMMAND.on_prepare_done(uid)
	return 0
end

-- 取消赛前准备完成
-- 1. 角色编号
function COMMAND.on_prepare_cancel(uid)
	return 0
end

-- 赛前准备完成（'准备完成/准备超时'触发）
function COMMAND.game_prepare_complete()
  return 0
end

-- 同步场景加载进度
-- 1. 角色编号
-- 2. 加载进度
function COMMAND.on_loading_progress(uid, value)
	return 0
end

-- 确定场景加载完成
-- 1. 角色编号
function COMMAND.on_loading_done(uid)
	return 0
end

-- 场景加载完成（'加载完成/加载超时'触发）
function COMMAND.game_loading_complete()
  return 0
end

-- 确定动画播放完成（包括倒计时动画）
-- 1. 角色编号
function COMMAND.on_ready_done(uid)
  return 0
end

-- 动画播放完成（'播放完成/播放超时'触发）
function COMMAND.game_ready_complete()
  return 0
end

-- 战场数据同步（数据不经过战场可以提高数据转发效率）
-- 1. 角色编号
-- 2. 战场数据
-- 3. 同步范围
function COMMAND.on_game_update(uid, data)
	return 0
end

-- 战场数据转发
-- 1. 角色编号
-- 2. 数据名称
-- 3. 数据内容
function COMMAND.on_game_forward(uid, name, data)
	return 0
end

-- 战场数据提交（客户端提交战场统计数据）
-- 1. 寄主编号
-- 2. 角色编号
-- 3. 统计数据
function COMMAND.on_game_submit(oid, uid, values)
	return 0
end

-- 确定完成比赛
-- 1. 寄主编号
-- 2. 角色编号
-- 3. 统计数据
function COMMAND.on_game_success(oid, uid, values)
	return 0
end

-- 启动比赛倒计时
function COMMAND.game_countdown_start()
  return 0
end

-----------------------------------------------------------
--- 结算相关逻辑
-----------------------------------------------------------


-- 比赛结算逻辑
function COMMAND.game_running_complete()
  return 0
end

-- 确定完成结算
function COMMAND.on_finish_done(uid)
  return 0
end

-- 战场关闭（延时关闭，确保用户成功返回组队服务）
function COMMAND.game_finish_complete()
  return 0
end

-- 成员掉线通知
function COMMAND.on_disconnect(uid)
  return 0
end

-- 成员重连通知
function COMMAND.on_reconnect(uid)
  return 0
end

-----------------------------------------------------------
--- 注册战场服务
-----------------------------------------------------------
service.register({
	CMD     = COMMAND,
})
