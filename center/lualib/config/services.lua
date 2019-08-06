local M = {}

M.list = {
    {
        name = GLOBAL.SERVICE_NAME.DATAMONGO,
        module = "db.datamongo",
    },
    {
        name = GLOBAL.SERVICE_NAME.USERCENTER,
        module = "usercenter",
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
    {
        name = GLOBAL.SERVICE_NAME.MAIL,
        module = "common.maild",
    },
    {
        name = GLOBAL.SERVICE_NAME.FRIEND,
        module = "common.friend",
    },
}

return M
