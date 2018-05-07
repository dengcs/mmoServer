-- 字符串分隔方法 
-- 1. 分隔字符串
function string:split(sep)
    local results = {}
    local pattern = string.format("([^%s]+)", (sep or "\t")) 
    self:gsub(pattern, function(c) results[#results+1] = c end)  
    return results
end

--表格式化字符串
--{aa.bb.cc}
function string.table_format(strFmt,tblVal)
    assert(type(strFmt) == "string")
    if not tblVal then
        return strFmt
    end 
    
    local retStr = strFmt
    
    local strPattern = "{[^}]*}" --模式字符串
    local strMatch = retStr:match(strPattern)
    
    if strMatch then
        local nCount = 0
        local nMaxCount = 100
        if type(tblVal) == "table" then --表的替换
            repeat
                -- strMatch格式为{aa.bb.cc}
                local strTblPattern = "[^{} ]+" --去除空格和大括号模式
                local strTblMatch = strMatch:match(strTblPattern)
                if not strTblMatch then
                    break
                end
                -- strTblMatch格式为aa.bb.cc
                local isFmtError = false
                local strList = strTblMatch:split('.')
                local finalVal = ""
                local copyVal = tblVal
                
                -- 找目标值
                for _,key in pairs(strList) do
                    local nKey = tonumber(key)
                    --判断下标为数值还是字符串
                    if not nKey then
                        nKey = key
                    end
                    if not copyVal[nKey] then
                        isFmtError = true
                        break
                    end
                    copyVal = copyVal[nKey]
                end
                
                if isFmtError then
                    break
                end
                
                if type(copyVal) ~= "table" then
                    finalVal = copyVal
                end
                
                retStr = retStr:gsub(strMatch, finalVal)
                strMatch = retStr:match(strPattern)
                
                nCount = nCount + 1
                if nCount > nMaxCount then
                    break
                end
            until(not strMatch)
        else --非表替换
            repeat
                retStr = retStr:gsub(strMatch, tblVal)
                
                strMatch = retStr:match(strPattern)
                
                nCount = nCount + 1
                if nCount > nMaxCount then
                    break
                end
            until(not strMatch)
        end
    end
    
    return retStr
end
