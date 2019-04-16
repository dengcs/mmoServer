---------------------------------------------------------------------
--- 区服数据服务配置
---------------------------------------------------------------------
local skynet = require "skynet"

-- 数据服务配置（缓存服务 + 存储服务）
local M = 
{
    -------------------------------
    --- 'MONGO'
    -------------------------------

    datamongod = {
        {
            category  = GLOBAL.DB.MONGO,
            host      = skynet.getenv("db_host"),
            port      = skynet.getenv("db_port"),
            auth      = skynet.getenv("db_auth"),
            password  = skynet.getenv("db_pass"),
            database  = skynet.getenv("db_name"),
            maxclient = 2,
        }
    }
}
return M
