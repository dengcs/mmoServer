-- 全局常量根节点
GLOBAL =
{
    ---------------------------------------------
    -- 数据库类型
    ---------------------------------------------
    DB =
    {
        UNKNOWN = 0,
        FSDISK  = 1,
        REDIS   = 2,
        MONGO   = 3,
        MYSQL   = 4,
    },
    ---------------------------------------------
    -- 服务别名
    ---------------------------------------------
    SERVICE_NAME =
    {
        SUMMARY     = ".summary",
        GATE        = ".gated",
        LOGICPROXY  = ".logicproxy",
        GAMEPROXY   = ".gameproxy",
        DATAMONGO   = ".datamongo",
        USERCENTER  = ".usercenter",
        GAME        = ".game",
        ROOM        = ".room",
        SOCIAL      = ".social",
        FRIEND      = ".friend",
        MAIL        = ".mail",
        CHAT        = ".chat",
        RANK        = ".rank",
    },
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
    ---------------------------------------------
    -- 资源类型
    ---------------------------------------------
    RESOURCE =
    {
        DIAMOND         = 1,                -- 钻石
        MONEY           = 2,                -- 货币
    }
}
