
local Random = {}

local randomseed = nil
local seed_size = 97

function Random.Get(m, n)
	-- 初始化随机数与随机数表，生成97个[0,1)的随机数
	if not randomseed then
		-- 避免种子过小
		math.randomseed(tonumber(tostring(os.time()):reverse():sub(1,6)))
		randomseed = {}
		for i = 1, seed_size do
			randomseed[i] = math.random()
		end
	end

	local x = math.random()
	local i = 1 + math.floor(seed_size*x)	-- i取值范围[1,97]
	x, randomseed[i] = randomseed[i], x	-- 取x为随机数，同时保证randomseed的动态性

	if not m then
		return x
	elseif not n then
		n = m
		m = 1
	end

	local offset = x*(n-m+1)
	return m + math.floor(offset)
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

