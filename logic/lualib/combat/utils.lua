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
	-- 1. 主类型
	-- 2. 子类型
	-- 3. 成员集合
	start = function(major, minor, users)
		-- 启动战场服务
		local ok, ret = skynet.call(GLOBAL.SERVICE_NAME.GAME, "lua", "on_create", major, minor, users)
		if ok ~= 0 then
			return nil
		else
			return ret
		end
	end,
}

-----------------------------------------------------------
--- 返回战斗工具集合
-----------------------------------------------------------
return utils
