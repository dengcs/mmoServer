local skynet    = require "skynet"
local service   = require "service_factory.service"

local server = {}

local connection_pools = {}

local initialized = false

-- 建立'redis'连接(注意返回值，等于0才是操作成功)
local function do_open(conf)
    -- 加载'redis'连接池模块
    local connection_pool = require "persistent.redis_connection_pool"
    -- 创建连接池实例对象
    local inst = connection_pool.new()
    -- 通过配置启动连接池
    local ok = inst:start(conf)
    if ok then
        inst:stop()
        return ok
    end
    -- 记录新建连接池（以数据源为关键字）
    connection_pools[conf.database] = inst
    return ok
end

-- 关闭'redis'连接
local function do_close(db)
    local inst = connection_pools[db]
    if inst then
        inst:stop()
        connection_pools[db] = nil
    end
end

-- 建立'redis'连接池
local function init_connection_pool()
    -- 获取数据库配置路径
    local datasource = skynet.getenv("datasource") or "config.datasource"
    if not datasource then
        ERROR(EFAULT, "Unknown datasource.")
        return EINVAL
    end
    -- 加载数据库配置信息
    local conf = require (datasource)
    assert(conf and conf.datacached)
    -- 建立'redis'连接
    for _, v in pairs(conf.datacached) do
        local database = v.database or 0
        local ok = do_open(v)
        if ok then
            return ok
        end
    end
    return 0
end

-- 管理'redis'连接池
local function cleanup_connection_pool()
    for k, inst in pairs(connection_pools) do
        assert(inst, "Unknown connection instance.")
        do_close(k)
    end
end

local CMD = {}

function CMD.call(source, db, cmd, ...)
    local pool = connection_pools[db]
    local inst = pool:sync_connection()
    if inst then
        return inst:call(cmd, ...)
    end
end

-- 数据查询操作(指定数据源)
-- 1. 命令来源
-- 2. 数据源
-- 3. 关键字
function CMD.query(source, db, key)
    -- 获取'redis'连接池对象
    local pool = assert(connection_pools[db], "db is nil")
    return pool:do_query("get", key)
end

-- 数据集查询操作（仅仅访问'redis'数据源）
-- 1. 命令来源
-- 2. 数据源
-- 3. 关键字
function CMD.get(source, db, key)
    local pool = assert(connection_pools[db], "db is nil")
    return pool:do_query("get", key)
end

-- '插入/更新'数据操作
-- 1. 命令来源
-- 2. 数据源
-- 3. 关键字
-- 4. 数据内容
function CMD.set(source, db, key, value, cached)
    -- 更新数据到'redis'数据库
    local pool = assert(connection_pools[db], "db is nil")
    return pool:do_update("set", key, value)
end

-- 删除指定数据（一般不会使用）
-- 1. 命令来源
-- 2. 数据源
-- 3. 关键字
function CMD.del(source, db, key)
    local pool = assert(connection_pools[db], "db is nil")
    return pool:do_update("del", key)
end

-- 判断'redis'中是否存在指定数据
-- 1. 命令来源
-- 2. 数据源
-- 3. 关键字
function CMD.exists(source, db, key)
    local pool = assert(connection_pools[db], "db is nil")
    return pool:do_query("exists", key)
end

-- ？？
function CMD.keys(source, db, key)
    local pool = assert(connection_pools[db], "db is nil")
    return pool:do_query("keys", key)
end

-- 服务初始通知
function server.init_handler(conf)
end

-- 服务退出通知
function server.exit_handler()
end

-- 服务启动通知
function server.start_handler()
    -- 防止重复启动
    assert(not initialized, "already starting")

    -- initialize local connection pool
    init_connection_pool()

    initialized = true

    return 0
end

-- 服务停止通知
function server.stop_handler()
    -- cleanup local connection pool
    cleanup_connection_pool()

    connection_pools = {}
    initialized = nil
    return 0
end

-- 内部命令分发
-- 1. 命令来源
-- 2. 命令名称
-- 3. 命令参数
function server.command_handler(source, cmd, ...)
    local f = CMD[cmd]
    if f then
        return f(source, ...)
    else
        ERROR(EFAULT, "call: %s: command not found", cmd)
    end
end

-- 服务启动
service.start(server)
