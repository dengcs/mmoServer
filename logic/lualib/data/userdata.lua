local hibernator = require "data.hibernator"
local userdata = {}

userdata.__index = userdata

-- 构建'userdata'对象
-- 1. 读写模式
function userdata.new(mode)
    local o = {
        mode = mode or "r",
        configure = {},
        datatable = {},
    }
    setmetatable(o, userdata)
    return o
end

-- 注册模块（角色由多个模块构成）
-- 1. 模块配置集合
function userdata:register(conf)
    for name, mod in pairs(conf) do
        local field = {}
        for k, v in pairs(mod) do
            field[k] = v
        end
        self.configure[name] = field
    end
end

-- 初始模块实例
-- 1. 模块名称
-- 2. 模块数据
-- 3. 可读标志
-- 4. 模块逻辑
local function create_instance(name, data, mode, cb)
    local inst = hibernator.new(name, data, mode)
    if cb then
        inst:register(cb)
    end
    return inst
end

local function load_cb(conf)
    -- 加载模型方法（）
    local cb = {}
    local inst_module = conf.require
    if type(inst_module) == "string" then
        local s = require(inst_module)
        cb = s
    elseif type(inst_module) == "table" then
        for _, subitem in pairs(inst_module) do
            local s = require(subitem)
            for k, v in pairs(s) do
                if type(v) == "function" then
                    cb[k] = v
                end
            end
        end
    else
        LOG_ERROR("Unknown config require value %s", type(inst_module))
    end
    return cb
end

-- '设置/绑定'模块数据
-- 1. 模块名称
-- 2. 模块数据
function userdata:init(name, data)
    -- 获取模块配置
    local conf = self.configure[name]
    assert(conf, string.format("Unknow config name %s", name))
    assert(not self.datatable[name], "Already exist hibernator object")
    -- 绑定模型
    local m         = self.mode     -- 可读标志
    local cb        = nil           -- 模型逻辑
    local init_func = nil           -- 初始逻辑
    if m == "w" then
        cb = load_cb(conf)
        if conf.on_init and conf.on_init ~= "" then
            init_func = conf.on_init
        end
    end

    -- 构造模块实例
    local inst = create_instance(name, data, m, cb)
    if not inst then
        error("hibernator object instance failed")
    end
    
    -- 初始模块实例
    if init_func then
        inst:call(init_func, m)
    end
    
    -- 绑定模块实例
    self.datatable[name] = inst
    
    return inst
end

function userdata:get(name)
    return self.datatable[name]
end

function userdata:all_data()
    return self.datatable
end

function userdata:cleanup(name)
    self.datatable[name] = nil
end

function userdata:cleanup_all()
    self.datatable = {}
end

function userdata:call(name, cmd, ...)
    assert(self.mode == "w", "Unknwon data mode")

    local m = self.datatable[name]
    if m then
        return m:call(cmd, ...)
    end
end

return userdata
