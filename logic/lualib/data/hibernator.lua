local sharemap = require "skynet.sharemap"

local hibernator = {}

function hibernator.new(name, data, mode)
    data = data or { }
    mode = mode or "r"

    local ret
    if mode == "r" then
        ret = sharemap.reader(name, data)
    elseif mode == "w" then
        ret = sharemap.writer(name, data)
    elseif mode == "v" then --访客模式
        local obj = {
            __typename = name,
            __data = data,
        }
        ret = setmetatable(obj, { __index = data })
    end

    return ret
end

return hibernator
