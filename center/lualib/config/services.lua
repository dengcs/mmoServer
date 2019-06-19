local M = {}

M.list = {
    {
        name = GLOBAL.SERVICE_NAME.DATAMONGOD,
        module = "db.datamongod",
        unique = true,
    },
    {
        name = GLOBAL.SERVICE_NAME.SOCIAL,
        module = "sociald",
        unique = true,
    },
    {
        name = GLOBAL.SERVICE_NAME.GAME,
        module = "combat.instance.game",
        unique = true,
    },
    {
        name = GLOBAL.SERVICE_NAME.ROOM,
        module = "combat.room",
        unique = true,
    },
    {
        name = GLOBAL.SERVICE_NAME.TOKEN,
        module = "token",
        unique = true,
    },
}

return M
