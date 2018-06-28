--
-- 战斗服务相关工具集合
--
local skynet = require "skynet"

-----------------------------------------------------------
--- 工具集合
-----------------------------------------------------------

local utils = 
{
	-- 开启战场服务
	-- 1. 战场主类型
	-- 2. 战场子类型
	-- 3. 赛道编号
	-- 4. 成员集合
	-- 5. 附加数据
	start = function(users)
		-- 启动战场服务
		local ret, id = skynet.call(GLOBAL.SERVICE_NAME.GAME, "on_create", users)
		if ret ~= 0 then
			return nil
		else
			return id
		end
	end,
}

-----------------------------------------------------------
--- 返回战斗工具集合
-----------------------------------------------------------
return utils
