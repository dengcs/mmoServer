local hibernator = require "data.hibernator"
local userdata = {}

-- 构建'userdata'对象
-- 1. 读写模式
function userdata.new(mode)
    local o = {
        mode        = mode or "r",
        configure   = {},
        datatable   = {},
        command     = {},
    }

    local mt = function(t, k)
        for _, m in ipairs({userdata, t.datatable}) do
            local v = m[k]
            if v ~= nil then
                return v
            end
        end
    end

    return setmetatable(o, { __index = mt })
end

-- 注册模块（角色由多个模块构成）
-- 1. 模块配置集合
function userdata:register(conf)
    self.configure = conf
end

local function load_cb(conf)
    -- 加载模型方法（）
    local cb = {}
    local inst_module = conf.require
    if type(inst_module) == "string" then
        cb = require(inst_module)
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

    if not self.datatable[name] then
        -- 绑定模型
        local m         = self.mode     -- 可读标志

        -- 构造模块实例
        local inst = hibernator.new(name, data, m)
        if not inst then
            LOG_ERROR("hibernator object instance failed")
        end

        -- 绑定模块实例
        self.datatable[name] = inst

        if m == "w" then
            self.command[name] = load_cb(conf)
            -- 初始模块实例
            self:call(name, "on_init")
        end
    end

    return self.datatable[name]
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
        local fn = self.command[name][cmd]
        if IS_FUNCTION(fn) then
            return fn(m, ...)
        end
    end
end

return userdata
