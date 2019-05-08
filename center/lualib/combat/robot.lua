---
--- Created by dcs.
--- DateTime: 2018/10/24 15:28
---

local robot = {}

local SEQUENCE  = 9000000
local function allocid()
	SEQUENCE = SEQUENCE + 1
	local robotId = string.format("Rt.%s", SEQUENCE)
	return robotId
end

function robot.generate_robot()
	local robot =
	{
		pid        = allocid(),
		sex        = 1,
		nickname   = "robot",
		portrait   = "portrait",
		ulevel     = 1,
		vlevel     = 0,
		score      = 0,
		portrait_box_id = 0,
		robot = true,
	}
	return robot
end

return robot