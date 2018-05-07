local connector = require "persistent.db_connector"
local mysql = require "skynet.db.mysql"

local mysql_connector = class("MysqlConnector", connector)

-- 构建数据库连接对象（设置连接器类型）
function mysql_connector:ctor()
    self.super.ctor(self)
    self.mode = GLOBAL.DB.MYSQL
end

-- 连接成功回调
local function on_connect(c)
    c:query("SET CHARSET UTF8")
end

-- 建立数据库连接
-- 1. 数据源地址
-- 2. 数据源端口
-- 3. 数据库名称
-- 4. 用户账号
-- 5. 用户密码
function mysql_connector:connect(host, port, db, auth, pwd)
    -- 建立数据库连接（底层连接）
    local connect = mysql.connect({
        host            = host,
        port            = port,
        database        = db,
        user            = auth,
        password        = pwd,
        max_packet_size = 1024 * 1024,
        on_connect      = on_connect,
    })
    if not connect then
        return ECONNREFUSED
    end
    -- 记录底层连接句柄
    self.connect = connect
    -- 回调通知连接建立
    if self.handler.connect_handler then
        self.handler:connect_handler(self)
    end
    return 0
end

-- 关闭数据库连接
function mysql_connector:disconnect()
    -- 确定底层连接存在
    local connect = self.connect
    if not connect then
        LOG_ERROR("illegal connection on mysql lib.")
        return
    end
    --  回调通知连接关闭
    if self.handler.disconnect_handler then
        self.handler:disconnect_handler(self)
    end
    -- 关闭数据库连接（底层连接）
    self.connect:disconnect()
    self.connect = nil
end

-- 获取指定数据
-- 1. SQL语句
function mysql_connector:get(key)
    return self.connect:query(key)
end

-- 更新指定数据
-- 1. SQL语句
-- 2. 无效内容
function mysql_connector:set(key)
    return self.connect:query(key)
end

-- 删除指定数据
-- 1. SQL语句
function mysql_connector:del(key)
    return self.connect:query(key)
end

-- 判断指定数据是否存在
-- 1. SQL语句
function mysql_connector:exists(key)
    return self.connect:query(key)
end

-- 列出全部键值
-- 1. SQL语句
function mysql_connector:keys(key)
    return self.connect:query(key)
end

return mysql_connector
