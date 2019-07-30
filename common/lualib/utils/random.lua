
local Random = {}

local randomseed = nil

function Random.Get(m, n)
	if not randomseed then
		randomseed = true
		local seedVal = tonumber(tostring(os.time()):reverse():sub(1,6))
		-- 避免种子过小
		math.randomseed(seedVal)
	end

	if m then
		return math.random(m)
	elseif n then
		return math.random(m, n)
	end

	return math.random()
end

return Random

