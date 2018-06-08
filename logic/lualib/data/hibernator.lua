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

        -- add custom property
        if ret then
            for k, v in pairs(hibernator) do ret[k] = v end
            ret.__name = name
            ret.__mode = mode
        end
    elseif mode == "v" then --访客模式
        local obj = {
            __typename = name,
            __data = data,
        }
    		ret = setmetatable(obj, { __index = data })
        for k, v in pairs(hibernator) do
            ret[k] = v
        end
        ret.__name = name
        ret.__mode = mode            
    end

    return ret
end

function hibernator:register(conf)
    self.__command = {}

    for k, v in pairs(conf) do
        self.__command[k] = v
    end
end

function hibernator:call(cmd, ...)
    local f = self.__command[cmd]
    if f then
        return f(self, ...)
    else
        LOG_ERROR("hibernator object command %s not found.", cmd)
    end
end

return hibernator
