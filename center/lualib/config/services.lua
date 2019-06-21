local M = {}

M.list = {
    {
        name = GLOBAL.SERVICE_NAME.DATAMONGOD,
        module = "db.datamongod",
    },
    {
        name = GLOBAL.SERVICE_NAME.USERCENTERD,
        module = "usercenterd",
        unique = true,
    },
    {
        name = GLOBAL.SERVICE_NAME.SOCIAL,
        module = "common.sociald",
    },
    {
        name = GLOBAL.SERVICE_NAME.GAME,
        module = "combat.instance.game",
    },
    {
        name = GLOBAL.SERVICE_NAME.ROOM,
        module = "combat.room",
    },
    {
        name = GLOBAL.SERVICE_NAME.TOKEN,
        module = "token",
    },
}

return M
