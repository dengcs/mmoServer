local table = table
local string = string
local assert = assert

setmetatable(_G, {
    __newindex = function (_, k)
        LOG_ERROR("Attempt to write undeclared variable " .. k)
        error("Attempt to write undeclared variable " .. k)
    end,
    __index = function (_, k)
        error("Attempt to read undeclared variable " .. k)
    end,
})

local handler = {}

--[[

上层业务服务启动管理，系统占用接口：
init    ：服务初始化调用接口
exit    ：服务退出销毁调用接口
start   ：服务启动调用接口
stop    ：服务停止调用接口
join    ：服务用户加入调用接口
leave   ：服务用户退出调用接口
push    ：服务群组通知调用接口
publish ：服务发布通知调用接口

]]

local web_handler = {}
local socket_handler = {}

-- 网络类的服务封装到子包中
handler.web = web_handler -- HTTP支持
handler.socket = socket_handler -- TCP/UDP支持

function handler.register(...)
    assert(not handler.instance, "service instance already exists")
    local instance = SERVICE_REGISTER("supported.__simple_service")
    return instance.register(...)
end

function handler.start(...)
    assert(not handler.instance, "service instance already exists")
    local instance = SERVICE_REGISTER("supported.__system_service")
    return instance.start(...)
end

function web_handler.start(...)
    assert(not handler.instance, "service instance already exists")
    local instance = require("supported.__web_service")
    return instance.start(...)
end

function socket_handler.start(...)
    assert(not handler.instance, "service instance already exists")
    local instance = SERVICE_REGISTER("supported.__socket_service")
    return instance.start(...)
end

return handler
