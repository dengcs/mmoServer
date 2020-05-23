--
-- 战斗服务相关工具集合
--
local cluster	= require "skynet.cluster"

-----------------------------------------------------------
--- 工具集合
-----------------------------------------------------------

local utils =
{
	-- 开启战场服务
	-- 1. 主类型
	-- 2. 子类型
	-- 3. 成员集合
	start = function(major, minor, data)
		-- 启动战场服务
		local ok, ret = cluster.call("arena", GLOBAL.SERVICE_NAME.GAME, "on_create", major, minor, data)
		if ok ~= 0 then
			return ok
		else
			return ret
		end
	end,
}

-----------------------------------------------------------
--- 返回战斗工具集合
-----------------------------------------------------------
return utils
