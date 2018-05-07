local connection_pool = class("ConnectionPool")

function connection_pool:ctor()
    self.mode            = GLOBAL.DB.UNKNOWN    -- 存储终端连接模式
    self.host            = nil                  -- 存储终端主机网络地址
    self.port            = nil                  -- 存储终端主机网络端口
    self.database        = nil                  -- 存储终端的库索引
    self.auth            = nil                  -- 存储终端网络连接身份验证的账号信息
    self.password        = nil                  -- 存储终端网络连接身份验证的密码信息
    self.connect_pools   = {}                   -- 存储终端缓冲池
    self.max_client      = 0                    -- 存储终端在连接池的最大连接数
    self.expression      = nil                  -- 存储终端外部特殊回调接口
    self.async_increment = 0                    -- 异步读方式增长索引
end

--[[

配置连接缓冲池的参数格式为表类型：
{
    host = "0.0.0.0", -- 连接的目的地址
    port = 10000, -- 连接的目标端口
    database = 0, -- 连接的库索引
    auth = "root", -- 连接时身份验证所用的账号信息
    password = "000000", -- 连接时身份验证所用的密码信息
    maxclient = 0, -- 连接的最大并发数量
    expression = "", -- 连接的外部回调句柄
}

]]

-- 设置连接池配置
local function connection_pool_configure(self, conf)
    self.host            = assert(conf.host)                -- 数据源地址
    self.port            = assert(conf.port)                -- 数据源端口
    self.database        = conf.database or ""              -- 数据源名称
    self.auth            = conf.auth or ""                  -- 账号/密码
    self.password        = conf.password or ""              -- 密码
    self.connect_pools   = {}                               -- 连接池
    self.max_client      = tonumber(conf.maxclient) or 0    -- 最大连接数
    self.async_increment = 0                                -- ？？
    self.expression      = conf.expression                  -- 扩展逻辑集合
end

local function init_async_index(self)
    assert(self.max_client >= 1)

    if self.max_client > 1 then
        return 2
    else
        return 1
    end
end

-- 启动数据库连接池
-- 1. 启动配置项
function connection_pool:start(conf)
    -- 设置连接池数据
    connection_pool_configure(self, conf)

    -- init async connection counter
    self.async_increment = init_async_index(self)
end

-- 连接成功后触发
-- 1. 连接对象
function connection_pool:connect_handler(inst)
    -- 设置数据库扩展接口
    if self.expression then
        local handler = require (self.expression)
        assert(handler)
        inst:register_expression(handler)
    end
    -- 记录数据库连接
    table.insert(self.connect_pools, inst)
end

-- 断开连接后触发（为什么不移除呢？？）
-- 1. 连接对象
function connection_pool:disconnect_handler(inst)
end

-- 释放全部数据库连接
local function close_all_connection(self)
    for index = 1, #self.connect_pools do
        local inst = self.connect_pools[index]
        if inst:is_connected() then
            inst:disconnect()
        end
    end
    self.connect_pools = {}
    self.max_client = 0
    self.async_increment = 0
end

-- 停止数据库连接池
function connection_pool:stop()
    close_all_connection(self)
end

---------------------------------------------------------------------
--- 数据库连接池支持两种数据库连接
--- 1. 专用连接 - 数据变更使用
--- 2. 查询连接 - 数据查询使用
--- 从而兼顾了写入顺序与查询效率
---------------------------------------------------------------------

-- 获得连接对象（固定首位连接对象？？）
function connection_pool:sync_connection()
    assert(self.max_client >= 1)
    return self.connect_pools[1]
end

-- 轮转获得连接对象
function connection_pool:async_connection()
    local inst = self.connect_pools[self.async_increment]
    self.async_increment = self.async_increment + 1
    if self.async_increment > self.max_client then
        self.async_increment = init_async_index(self)
    end
    return inst
end

-- 数据请求操作（数据请求可以使用不同网络连接，确保效率）
-- 1. 操作名称
-- 2. 操作参数
function connection_pool:do_query(cmd, ...)
    -- 获得数据库连接对象
    local connector = self:async_connection()
    -- 指定指定操作
    local f = connector[cmd]
    if f then
        return f(connector, ...)
    else
        LOG_ERROR("query: %s: command not found", cmd)
    end
end

-- 数据请求操作（数据变更尽量用同一网络连接，确保顺序）
-- 1. 操作名称
-- 2. 操作参数
function connection_pool:do_update(cmd, ...)
    local connector = self:sync_connection()
    local f = connector[cmd]
    if f then
        return f(connector, ...)
    else
        LOG_ERROR("update: %s: command not found", cmd)
    end
end

return connection_pool
