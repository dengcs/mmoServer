local skynet = require "skynet"
require "skynet.manager"

local service = require "service_factory.service"
local method = require "method"

setmetatable(_G, {
    __newindex = function (_, k)
        error("Attempt to write undeclared variable " .. k)
    end,
    __index = function (_, k)
        error("Attempt to read undeclared variable " .. k)
    end,
})

--[[

摘要管理器相关属性记录格式：
    {
        module: 启动目标服务所需的模块路径
        name: 供任务管理器调度所用的服务别名
        master: 服务部署类型，参考‘GLOBAL.MASTER_TYPE’宏定义
        proto: 服务协议类型，参考‘GLOBAL.PROTO_TYPE’宏定义
        unique: 服务启动模式类型，可设置全局唯一或多实例类型
        auto：服务启动管理类型，可设为自动/手动进行启动指令触发
        collect: 服务内存回收类型，可设为自动/手动方式进行回收管理
        delegate: 服务外部提供支持的回调模块路径
    }

]]

local server = {}

local service_mapping = {}
local service_open_order_list = {} -- 服务实例的启动顺序
local service_gclist = {}

-- 外部委托接口自动配置的映射列表
-- 若用户已设置委托代理，则忽略该配置
-- 若用户未设置委托代理，且配置中存在对应服务名称的委托接口配置参数，则自动设置到该服务的初始配置中
local delegate_mapping = {}

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

        -- ？？
        if not conf.master then
            conf.master = GLOBAL.MASTER_TYPE.SUMMD
        end

        -- ？？
        if not conf.delegate then
            conf.delegate = delegate_mapping[name]
        end

        -- 服务初始化调用
        local err
        local ok, result = skynet.call(service, "lua", "init", conf)
        if ok > 0 then
            err = result
        elseif result > 0 then
            err = EXCEPTION_MESSAGE(ECOMM, "call: %s: function caused service abort", name)
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

    function CMD.open(_, conf)
        return do_open(conf)
    end

    function CMD.close(_, name)
        return do_close(name)
    end


    function CMD.autoload(_, conf)
        if not conf then
            ERROR(EINVAL, "autoload: taskserver: unknown service configure")
        end
        -- 遍历配置项，
        for _, v in pairs(conf) do
            v.auto = true
            local s = do_open(v)
            -- 服务初始化过程
            if v.init then
                for _, c in pairs(v.init) do
                    assert(c.func, string.format("call: %s: init function must be non-nil", v.name))
                    method.call(s, c.func, c.args)
                end
            end
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

    function CMD.query(_, name)
        return do_query(name)
    end

    -- 'summd'服务初始化通知
    -- 1. 初始化配置
    function handler.init_handler(conf)
        if conf.agent_list then
            delegate_mapping = {}

            for _, v in pairs(conf.agent_list) do
                assert(v.name and v.file, "invalid arguments")

                delegate_mapping[v.name] = v.file
            end
        end
    end

    function handler.exit_handler()
        -- 按顺序关闭服务
        for i=#service_open_order_list,1,-1 do
            do_close(service_open_order_list[i])
        end

        service_mapping = {}
        service_gclist = {}

        delegate_mapping = {}

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
            return f(source, ...)
        else
            return conf.command_handler(source, cmd, ...)
        end
    end

    service.start(handler)
end

return server
