local skynet  = require "skynet"

local tinsert = table.insert
local tremove = table.remove

local Player = {}

function Player:on_init()
  self.nickname = self.nickname or ""
  self.portrait = self.portrait or ""
  self.sex      = self.sex or 1
  self.level    = self.level or 1
  self.score 	= self.score or 0
end

-- 角色创建操作
function Player:on_create()
	
end

-- 角色登录操作
function Player:on_login(pid)
	self.state = 1
end

-- 唤醒处理
function Player:on_waken()
end

function Player:on_logout(user)
end

-- afk处理
function Player:on_afk(user)
end

-- 获取玩家基础信息
function Player:get_player_info()
end

-- 角色快照
function Player:get_snapshot()
	local snapshot = 
	{
		pid = self.pid,
		nickname = self.nickname,
		portrait = self.portrait,
		level = self.level,
		sex = self.sex,
		score = self.score
	}
	
	return snapshot
end

return Player