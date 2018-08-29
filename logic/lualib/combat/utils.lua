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
-- 1. 战场主类型
-- 2. 战场子类型
local function allocid(major, minor)
	SEQUENCE = SEQUENCE + 1
	return string.format("%x", ((major & 0xF) << 46) + ((minor & 0xF) << 42) + SEQUENCE)
end

local utils = 
{
	-- 开启战场服务
	-- 1. 战场主类型
	-- 2. 战场子类型
	-- 3. 成员集合
	start = function(major, minor, users)
		local alias = allocid(major, minor)
		local game = skynet.summdriver.newservice("combat/instance/game", alias, GLOBAL.PROTO_TYPE.TERMINAL)
		if not game then
			return nil
		end
		-- 启动战场服务
		local ok, ret = skynet.call(alias, "on_create", major, minor, users)
		if ok ~= 0 or ret ~= 0 then
			skynet.summdriver.closeservice(alias)
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
