local skynet  = require "skynet"

local tinsert = table.insert
local tremove = table.remove

local Player = {}

function Player:on_init()
  self.uid      = self.uid or ""
  self.nickname = self.nickname or ""
  self.portrait = self.portrait or ""
  self.sex      = self.sex or 1
  self.level    = self.level or 1
  self.experience = self.experience or 0
  
  print("dcs----on_init")
end

-- 角色创建操作
function Player:on_create(user, name, sex, portrait)
end

-- 角色快照
function Player:get_snapshot()
end

-- 角色登录操作
function Player:on_login(user)
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

return Player