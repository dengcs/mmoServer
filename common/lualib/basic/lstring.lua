-- 字符串分隔方法 
-- 1. 分隔字符串
function string:split(sep)
    local results = {}
    local pattern = string.format("([^%s]+)", (sep or "\t")) 
    self:gsub(pattern, function(c) results[#results+1] = c end)  
    return results
end