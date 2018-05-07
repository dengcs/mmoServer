local connector = class("Connector")

function connector:ctor()
    self.mode       = GLOBAL.DB.UNKNOWN -- 连接器的开启模式
    self.connect    = nil -- 终端连接实例
    self.handler    = {} -- 外部访问的回调句柄
    self.expression = {} -- 外部操作的回调句柄
end

function connector:connect(host, port, db, auth, pwd)
    error("This function is not implemented.")
end

function connector:disconnect()
    error("This function is not implemented.")
end

-- 判断是否连接数据库
function connector:is_connected()
    return (not self.connect)
end

function connector:get(key)
    error("This function is not implemented.")
end

function connector:set(key, value)
    error("This function is not implemented.")
end

function connector:del(key)
    error("This function is not implemented.")
end

function connector:exists(key)
    error("This function is not implemented.")
end

function connector:keys(key)
    error("This function is not implemented.")
end

-- 注册数据库回调通知逻辑
function connector:register_handler(handler)
    if type(handler) == "string" then
        -- 加载
        local conf = require (handler)

        assert(conf)
        self.handler = conf
    elseif type(handler) == "table" then
        self.handler = handler
    else
        LOG_ERROR("connect: register: could not parse handler %s", tostring(handler))
    end
end

-- 注册数据库扩展操作逻辑
function connector:register_expression(expression)
    if type(expression) == "string" then
        local conf = require (expression)

        assert(conf)
        self.expression = conf
    elseif type(expression) == "table" then
        self.expression = expression
    else
        LOG_ERROR("connect: register: could not parse expression %s", tostring(expression))
    end
end

-- 这里提供数据库扩展操作
-- expression : 提供扩展操作逻辑
function connector:call(cmd, ...)
    local f

    if self.expression then
        f = self.expression[cmd]
    end

    if f then
        return f(self.connect, ...)
    else
        ERROR(EBADMSG, "call: %s: command not found", cmd)
    end
end

return connector
