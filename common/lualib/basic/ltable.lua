-- assignment copy
table.clone = function (t, nometa)
    local result = {}
    if not nometa then
        setmetatable(result, getmetatable(t))
    end
    for k, v in pairs(t) do
        result[k] = v
    end
    return result
end

-- deep copy
table.deep_clone = function (t, nometa)
    local result = {}
    if not nometa then
        setmetatable(result, getmetatable(t))
    end
    for k, v in pairs(t) do
        if type(v) == "table" then
            result[k] = table.deep_clone(v)
        else
            result[k] = v
        end
    end
    return result
end

-- check the table include target value
table.contains = function (t, nometa)
    if t then
        for _, v in pairs(t) do
            if v == nometa then
                return true
            end
        end
    end
    return false
end

-- append value to the end of the original table
table.append = function (t, o)
    if t then
        for k, v in pairs(o) do
            t[k] = v
        end
    end
    return t
end

table.empty = function (t)
    if type(t) == "table" and next(t) then
        return false
    end
    return true
end

-- extract the node values of a tree table
table.extract = function (t, key)
    if type(t) ~= "table" then
        return nil
    end

    if type(key) == "table" then
        local result = t
        for _, v in pairs(key) do
            result = result[v]
            if not result then
                break
            end
        end

        return result
    else
        return t[key]
    end
end

table.lextract = function (t, key, ...)
    if key then
        t = table.lextract(t[key], ...)
    end

    return t
end

local __MAX_TABLE_DEPTH = 9

local function __dump_tab(depth)
    local buffer = ""
    for n = 1, depth do
        buffer = buffer .. "\t"
    end
    return buffer
end

local function __dump_table(t, depth)
    local tp = type(t)
    local buffer = ""
    if tp == "table" then
        local dt = depth + 1
        if dt > __MAX_TABLE_DEPTH then
            buffer = buffer .. "..."
            return buffer
        end

        buffer = buffer .. "{\n"
        depth = depth + 1
        for k, v in pairs(t) do
            buffer = buffer .. __dump_tab(depth) .. tostring(k) .. " = "
            if type(v) == "table" then
                buffer = buffer .. __dump_table(v, depth)
            else
                buffer = buffer .. tostring(v)
            end

            if depth ~= 0 then
                buffer = buffer .. ","
            end
            buffer = buffer .. "\n"
        end

        depth = depth - 1
        buffer = buffer .. __dump_tab(depth) .. "}"
    else
        buffer = buffer .. tostring(t)
    end
    return buffer
end

table.tostring = function (t)
    if type(t) ~= "table" then
        return string.format("type is not table,type = %s",type(t))
    end
    return __dump_table(t, 0)
end
