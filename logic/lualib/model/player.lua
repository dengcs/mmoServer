tb_insert	= table.insert

local Player = {}

function Player:on_init()
  	self.portrait 	= self.portrait or ""
  	self.sex      	= self.sex or 1
  	self.level    	= self.level or 1
  	self.score 		= self.score or 0
	self.resources	= self.resources or {}
end

-- 角色创建操作
function Player:on_create()
	
end

-- 角色登录操作
function Player:on_login()
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

-- 增加资源数量
-- 1. 资源类型
-- 2. 资源增量
function Player:add_resource(category, increment)
	for _,resource in pairs(self.resources) do
		if resource.category == category then
			resource.balance = resource.balance + increment
			self:commit()
			return
		end
	end

	tb_insert(self.resources, { category = category, balance = 0, expense = 0 })
	self:commit()
end

-- 扣除资源数量
-- 1. 资源类型
-- 2. 资源减量
function Player:del_resource(category, decrement)
	for _,resource in pairs(self.resources) do
		if resource.category == category then
			resource.balance = math.max(0, resource.balance - decrement)
			resource.expense = resource.expense + decrement
			self:commit()
			break
		end
	end
end

-- 判断资源是否足够
-- 1. 资源类型
-- 2. 资源数量
function Player:enough_resource(category, amount)
	for _,resource in pairs(self.resources) do
		if resource.category == category then
			return resource.balance >= amount
		end
	end

	return false
end

-- 获取资源数量
-- 1. 资源类型
function Player:get_resource(category)
	for _,resource in pairs(self.resources) do
		if resource.category == category then
			return resource.balance
		end
	end

	return 0
end

return Player