
local Random = {}

local randomseed = nil

function Random.Get(m, n)
	if not randomseed then
		-- 避免种子过小
		math.randomseed(tonumber(tostring(os.time()):reverse():sub(1,6)))
	end

	if n then
		return math.random(m, n)
	elseif m then
		return math.random(m)
	end
	return math.random()
end

-- 取得[m, n]连续范围内的k个不重复的随机数
function Random.GetRange(m, n, k)

	local t = {}
	for i = m, n do
		t[#t + 1] = i
	end

	local size = #t
	for i = 1, k do
		local x = Random.Get(i, size)
		t[i], t[x] = t[x], t[i]		-- t[i]与t[x]交换
	end

	local result = {}
	for i = 1, k do
		result[#result + 1] = t[i]
	end

	return result
end

return Random

