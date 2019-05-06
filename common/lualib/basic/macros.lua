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

GLOBAL.SERVICE_NAME =
{
    SUMMD       = ".summd",
    GATED       = ".gated",
    LOGICPROXY  = ".logicproxy",
    DATAMONGOD  = ".datamongo",
    USERCENTERD = ".usercenter",
    GAME        = ".game",
    ROOM        = ".room",
    TOKEN       = ".token",
    SOCIAL      = ".social",
}

GAME = 
{
    ---------------------------------------------
    -- 业务数据类型枚举
    ---------------------------------------------
    COLLECTIONS =
    {
        -- 角色相关数据类型
        PLAYER        = 10,    -- 角色信息
        SOCIAL        = 11,    -- 社交信息
    },
}
