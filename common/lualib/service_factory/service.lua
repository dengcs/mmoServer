local assert = assert

setmetatable(_G, {
    __index = function (_, k)
        error("Attempt to read undeclared variable " .. k)
    end,
})

local handler = {}

local web_handler = {}

-- 网络类的服务封装到子包中
handler.web = web_handler -- HTTP支持

function handler.start(...)
    assert(not handler.instance, "service instance already exists")
    local instance = require("supported.__simple_service")
    return instance.start(...)
end

function web_handler.start(...)
    assert(not handler.instance, "service instance already exists")
    local instance = require("supported.__web_service")
    return instance.start(...)
end

return handler
