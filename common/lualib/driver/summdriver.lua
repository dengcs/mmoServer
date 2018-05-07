local skynet = require "skynet.manager"

local summdriver = {}

local handler_mapping = {}

local function __send(command, ...)
    skynet.send(GLOBAL.SERVICE_NAME.SUMMD, "lua", command, ...)
end

local function __call(command, ...)
    return skynet.call(GLOBAL.SERVICE_NAME.SUMMD, "lua", command, ...)
end

local function configure(conf)
    if not conf then
        handler_mapping = {}
    end

    for k, v in pairs(conf) do
        assert(v.name and v.file, "invalid arguments")

        handler_mapping[v.name] = v.file
    end
end

-- 启动'summd'服务
-- 1. 启动配置（关联服务列表）
function summdriver.start()
    local summd = skynet.uniqueservice("summd")
    skynet.name(GLOBAL.SERVICE_NAME.SUMMD, summd)

    -- configure(conf)
    skynet.call(summd, "lua", "init", {
        name = GLOBAL.SERVICE_NAME.SUMMD,
        unique = true,
        proxy = true,
        auto = true,
    })
end

function summdriver.close()
    __call("exit")
end

function summdriver.autoload(t)
    return __call("autoload", t)
end

function summdriver.newservice(module, name, proto)
    return __call("open", {
        module = module,
        name = name,
        master = GLOBAL.MASTER_TYPE.SUMMD,
        proto = proto,
        unique = false,
        proxy = false,
    })
end

function summdriver.uniqueservice(module, name, proto)
    return __call("open", {
        module = module,
        name = name,
        master = GLOBAL.MASTER_TYPE.SUMMD,
        proto = proto,
        unique = true,
        proxy = false,
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

-- 加入服务
function summdriver.join(name, uid, cb)
    return __call("join", name, uid, skynet.self(), cb)
end

-- 离开服务
function summdriver.leave(name, uid)
    return __call("leave", name, uid)
end

return summdriver
