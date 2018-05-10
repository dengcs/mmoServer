---
--- 位操作工具集（按'LuaBitOp'版本实现）
---
local bit = {}

-- 取反操作
function bit.bnot(v)
	return ~v
end

-- 与操作
function bit.band(m, ...)
	local ret = m
	for _, v in pairs({...}) do
		ret = ret & v
	end
	return ret
end

-- 或操作
function bit.bor(m, ...)
	local ret = m
	for _, v in pairs({...}) do
		ret = ret | v
	end
	return ret
end

-- 异或操作
function bit.bxor(m, ...)
	-- 内部异或操作
	local function xor(a, b)
		local ret = 0
		for i = 32, 0, -1 do
			local vv = 2 ^ i
			local aa = false
			local bb = false
			if a == 0 then
				ret = ret + b
				break
			end
			if b == 0 then
				ret = ret + a
				break
			end
			if a >= vv then
				aa = true
				a  = a - vv
			end
			if b >= vv then
				bb = true
				b  = b - vv
			end
			if not (aa and bb) and (aa or bb) then
				ret = ret + vv
			end
		end
		return ret
	end
	-- 异或操作逻辑
	local ret = m
	for _, v in pairs({...}) do
		ret = xor(ret, v)
	end
	return ret
end

-- 左移操作
function bit.lshift(number, offset)
	local res = number * (2 ^ offset)
	return res % (2 ^ 32)
end

-- 右移操作
function bit.rshift(number, offset)
	local res = number / (2 ^ offset)
	return math.floor(res)
end

-- 导出模块
return bit
