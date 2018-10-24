local skynet = require "skynet_ex"
local service = require "service_factory.service"

--[[

摘要管理器相关属性记录格式：
    {
        module: 启动目标服务所需的模块路径
        name: 供任务管理器调度所用的服务别名
        unique: 服务启动模式类型，可设置全局唯一或多实例类型
        auto：服务启动管理类型，可设为自动/手动进行启动指令触发
        collect: 服务内存回收类型，可设为自动/手动方式进行回收管理
    }

]]

local server = {}

local service_mapping = {}
local service_open_order_list = {} -- 服务实例的启动顺序
local service_gclist = {}

-- 通过名称获取服务句柄？？
function server.do_query(name)
    return service_mapping[name]
end

function server.start(conf)
    assert(conf.command_handler)

    local _open_handler  = conf.open_handler
    local _close_handler = conf.close_handler

    local handler = {}

    local CMD = {}

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
            print("dcs--name--"..name)
            skynet.name(name, service)
        end

        -- 通知业务逻辑服务启动
        if _open_handler then
            _open_handler(name, service)
        end

        -- 记录服务对象
        service_mapping[name] = service
        service_gclist[name]  = collect
        table.insert(service_open_order_list, name)

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

    -- 关闭指定服务
    local function do_close(name)
        local service = service_mapping[name]
        skynet.call(service, "lua", "exit")

        service_mapping[name] = nil
        service_gclist[name] = nil
        
        for k, v in pairs(service_open_order_list) do
            if v == name then
                table.remove(service_open_order_list, k)
                break
            end
        end

        if _close_handler then
            _close_handler(name)
        end

        return 0
    end

    function CMD.open(conf)
        return do_open(conf)
    end

    function CMD.close(name)
        return do_close(name)
    end


    function CMD.autoload(conf)
        if not conf then
            ERROR(EINVAL, "autoload: taskserver: unknown service configure")
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
                skynet.send(s, "lua", "collect")
            end
        end

        this.send("collect")
    end

    function CMD.query(name)
        return do_query(name)
    end

    -- 'summd'服务初始化通知
    -- 1. 初始化配置
    function handler.init_handler(conf)
    end

    function handler.exit_handler()
        -- 按顺序关闭服务
        for i=#service_open_order_list,1,-1 do
            do_close(service_open_order_list[i])
        end

        service_mapping = {}
        service_gclist = {}

        if conf.exit_handler then
            conf.exit_handler()
        end
    end

    function handler.start_handler(...)
    end

    function handler.stop_handler()
    end

    -- 服务消息分发逻辑
    -- 1. 消息来源
    -- 2. 消息类型
    -- 3. 消息内容
    function handler.command_handler(source, cmd, ...)
        local f = CMD[cmd]
        if f then
            return f(...)
        else
            return conf.command_handler(source, cmd, ...)
        end
    end

    service.start(handler)
end

return server
