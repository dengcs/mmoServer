local skynet = require "skynet.manager"

local summdriver = {}

local function __send(command, ...)
    skynet.send(GLOBAL.SERVICE_NAME.SUMMD, "lua", command, ...)
end

local function __call(command, ...)
    return skynet.call(GLOBAL.SERVICE_NAME.SUMMD, "lua", command, ...)
end

-- 启动'summd'服务
-- 1. 启动配置（关联服务列表）
function summdriver.start()
    local summd = skynet.uniqueservice("summd")
    skynet.name(GLOBAL.SERVICE_NAME.SUMMD, summd)

    skynet.call(summd, "lua", "init", {
        name = GLOBAL.SERVICE_NAME.SUMMD,
        unique = true,
        auto = true,
    })
end

function summdriver.close()
    __call("exit")
end

function summdriver.autoload(t)
    return __call("autoload", t)
end

function summdriver.newservice(module, name)
    return __call("open", {
        module = module,
        name = name,
        unique = false,
        auto = true,
    })
end

function summdriver.uniqueservice(module, name)
    return __call("open", {
        module = module,
        name = name,
        unique = true,
        auto = true,
    })
end

function summdriver.closeservice(name)
    return __call("close", name)
end

function summdriver.send(name, command, ...)
    __send("send", name, command, ...)
end

function summdriver.call(name, command, ...)
    return __call("call", name, command, ...)
end

-- function summdriver.schedule(name, address, cb, args, interval, loop)
--     return skynet.call(GLOBAL.SERVICE_NAME.SCHEDULED, "lua", "schedule", name, address, GLOBAL.MASTER_TYPE.SUMMD, cb, args, interval, loop)
-- end

-- function summdriver.reschedule(name, address, cb, args, interval, loop)
--     return skynet.call(GLOBAL.SERVICE_NAME.SCHEDULED, "lua", "reschedule", name, address, GLOBAL.MASTER_TYPE.SUMMD, cb, args, interval, loop)
-- end

-- function summdriver.unschedule(name)
--     skynet.send(GLOBAL.SERVICE_NAME.SCHEDULED, "lua", "unschedule", name)
-- end

return summdriver
