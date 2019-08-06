local skynet    = require "skynet_ex"
local service   = require "factory.service"

local tb_insert = table.insert

---------------------------------------------------------------------
--- 内部变量/内部逻辑
---------------------------------------------------------------------
local service_mapping = {}
local service_open_order_list = {} -- 服务实例的启动顺序
local service_gclist = {}

-- 查询指定服务
local function do_query(name)
    return service_mapping[name]
end

-- 关闭指定服务
local function do_close(name)
    local service = service_mapping[name]

    if service then
        skynet.call(service, "lua", "exit")
        service_mapping[name] = nil
    end

    return 0
end

-- 开启配置对应服务？？
-- 1. 启动配置项
local function do_open(conf)
    local module  = conf.module                 -- 服务脚本文件
    local name    = conf.name                   -- 服务名称
    local unique  = conf.unique                 -- 是否唯一服务
    local collect = conf.collect or "false"     -- 自动垃圾回收

    -- 指定服务构造
    local service
    module = string.gsub(module, "%.", "/")
    if IS_TRUE(unique) then
        service = skynet.uniqueservice(module)
    else
        service = skynet.newservice(module)
    end

    -- 绑定服务名称
    if name then
        skynet.name(name, service)
    end

    -- 记录服务对象
    service_mapping[name] = service
    service_gclist[name]  = collect
    tb_insert(service_open_order_list, name)

    -- 服务初始化调用
    local err
    local ok, result = skynet.call(service, "lua", "init", conf)
    if ok > 0 then
        err = result
    end

    if err then
        do_close(name)
        ERROR(err)
    end

    return service
end

---------------------------------------------------------------------
--- 服务导出接口
---------------------------------------------------------------------

local CMD = {}

function CMD.send(name, cmd, ...)
    local service = do_query(name)
    if not service then
        ERROR(EFAULT, "find: %s: no such function or service", name)
    end

    skynet.send(service, "lua", cmd, ...)
end

function CMD.call(name, cmd, ...)
    local service = do_query(name)
    if not service then
        ERROR(EFAULT, "find: %s: no such function or service", name)
    end

    local ok, result = skynet.call(service, "lua", cmd, ...)
    if ok ~= 0 then
        ERROR(ok, result)
    end

    return result
end

function CMD.open(conf)
    return do_open(conf)
end

function CMD.close(name)
    return do_close(name)
end


function CMD.autoload(conf)
    if not conf then
        ERROR(EINVAL, "autoload: unknown service configure")
    end

    -- 遍历配置项，
    for _, v in pairs(conf) do
        v.auto = true
        do_open(v)
    end

    return 0
end

function CMD.gc()
    for k, v in pairs(service_gclist) do
        if IS_TRUE(v) then
            local s = service_mapping[k]
            if s then
                skynet.send(s, "lua", "collect")
            end
        end
    end

    this.send("collect")
end

function CMD.query(name)
    return do_query(name)
end

---------------------------------------------------------------------
--- 服务事件回调（底层事件通知）
---------------------------------------------------------------------
local server = {}

-- 服务退出通知
function server.exit_handler()
    -- 按顺序关闭服务
    local len = #service_open_order_list
    for i=len,1,-1 do
        do_close(service_open_order_list[i])
    end
end

function server.command_handler(source, cmd, ...)
    local f = CMD[cmd]
    if f then
        return f(...)
    else
        ERROR(EFAULT, "call: %s: command not found", cmd)
    end
end

service.start(server)