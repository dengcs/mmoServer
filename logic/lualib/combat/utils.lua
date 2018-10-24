--
-- 战斗服务相关工具集合
--
local skynet = require "skynet_ex"

local summdriver = skynet.summdriver()
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
	return string.format(".%x", ((major & 0xF) << 46) + ((minor & 0xF) << 42) + SEQUENCE)
end

local utils = 
{
	-- 开启战场服务
	-- 1. 主类型
	-- 2. 子类型
	-- 3. 成员集合
	start = function(major, minor, users)
		local alias = allocid(major, minor)
		local game = summdriver.newservice("combat/instance/game", alias)
		if not game then
			return nil
		end
		-- 启动战场服务
		local ok = skynet.call(alias, "lua", "on_create", alias, users)
		if ok ~= 0 then
			summdriver.closeservice(alias)
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
