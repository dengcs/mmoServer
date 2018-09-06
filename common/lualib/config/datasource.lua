---------------------------------------------------------------------
--- 区服数据服务配置
---------------------------------------------------------------------
local skynet = require "skynet"

-- 数据库名称枚举
local DB = 
{
	REDIS_A = GAME.META.PLAYER,
	REDIS_B = 11,
	MYSQLDB = skynet.getenv("db_name") or "test",
}

-- 数据服务配置（缓存服务 + 存储服务）
local M = 
{
		-------------------------------
		--- 'MYSQL'
		-------------------------------
		databased = {
			category  = GLOBAL.DB.MYSQL,
			host      = skynet.getenv("db_host") or "192.168.188.82",
			port      = skynet.getenv("db_port") or "3306",
			auth      = skynet.getenv("db_auth") or "test",
			password  = skynet.getenv("db_pass") or "123456",
			database  = DB.MYSQLDB,
			maxclient = 2,
		},
		
		-------------------------------
        --- 'REDIS'
        -------------------------------
        
        datacached = {
              {
                category  = GLOBAL.DB.REDIS,
                host      = skynet.getenv("dc_host") or "192.168.188.82",
                port      = skynet.getenv("dc_port") or "10002",
                auth      = skynet.getenv("dc_auth") or "888888",
                password  = "",
                database  = DB.REDIS_A,
                maxclient = 2,
              },
              {
                category  = GLOBAL.DB.REDIS,
                host      = skynet.getenv("dc_host") or "192.168.188.82",
                port      = skynet.getenv("dc_port") or "10002",
                auth      = skynet.getenv("dc_auth") or "888888",
                password  = "",
                database  = DB.REDIS_B,
                maxclient = 2,
              },
        }
}
return M
