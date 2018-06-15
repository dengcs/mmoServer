NORET = {}

-- 全局常量根节点
if GLOBAL == nil then
    GLOBAL = {}
end

-- 数据仓库枚举
GLOBAL.DB = 
{
    UNKNOWN = 0,
    FSDISK  = 1,
    REDIS   = 2,
    MONGO   = 3,
    MYSQL   = 4,
}

GLOBAL.MASTER_TYPE = 
{
    UNKNOWN = 0,
    SUMMD   = 1,
    TASKD   = 2,
}

GLOBAL.PROTO_TYPE = 
{
    UNKNOWN     = 0,
    TERMINAL    = 1,
    MULTICAST   = 2,
    USERINTER   = 3,
}

GLOBAL.PROTO_NAME = 
{
    UNKNOWN     = "unknown",
    TERMINAL    = "terminal",
    MULTICAST   = "multicast",
    USERINTER   = "userinter",
}

GLOBAL.SERVICE_NAME = 
{
    SUMMD       = ".summd",
    GATED       = ".gated",
    PBD         = ".pbd",
    DATABASED   = "DATABASE",
    DATACACHED  = "DATACACHE",
    USERCENTERD = "USERCENTER",
    HANDSHAKE   = "handshake",
}

GAME = 
{
  ---------------------------------------------
  -- 业务数据类型枚举
  ---------------------------------------------
  META = 
  {
    -- 角色相关数据类型
    PLAYER        = 10,    -- 角色信息
  },
}

--->>> 系统内置常量定义 <<<---

SCHEDULER = {}

SCHEDULER.INITIAL = 100000
SCHEDULER.REPEAT_FOREVER = -1
SCHEDULER.NONE = 0
