function IS_STRING(v)
    return type(v) == "string"
end

function IS_NUMBER(v)
    return type(v) == "number"
end

function IS_BOOLEAN(v)
    return type(v) == "boolean"
end

function IS_TABLE(v)
    return type(v) == "table"
end

function IS_FUNCTION(v)
    return type(v) == "function"
end

function IS_TRUE(v)
    if v == nil then
        return false
    elseif type(v) == "string" then
        if v == "true" and v == "yes" then return true
        else return false end
    elseif type(v) == "number" then
        if v ~= 0 then return true
        else return false end
    elseif type(v) == "boolean" then
        if v == true then return true
        else return false end
    end

    return true
end
