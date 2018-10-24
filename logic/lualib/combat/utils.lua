--
-- 战斗服务相关工具集合
--
local skynet = require "skynet_ex"

-----------------------------------------------------------
--- 工具集合
-----------------------------------------------------------

-- 步进序号
local SEQUENCE  = 0

-- 生成编号(50位整数)
-- 1. 主类型
-- 2. 子类型
local function allocid(major, minor)
	SEQUENCE = SEQUENCE + 1
	return string.format("%x", ((major & 0xF) << 46) + ((minor & 0xF) << 42) + SEQUENCE)
end

local utils = 
{
	-- 开启战场服务
	-- 1. 主类型
	-- 2. 子类型
	-- 3. 成员集合
	start = function(major, minor, users)
		local alias = allocid(major, minor)
		-- 启动战场服务
		local ok = skynet.call(GLOBAL.SERVICE_NAME.GAME, "lua", "on_create", alias, users)
		if ok ~= 0 then
			return nil
		else
			return alias
		end
	end,
}

-----------------------------------------------------------
--- 返回战斗工具集合
-----------------------------------------------------------
return utils
