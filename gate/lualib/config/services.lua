local M = {}

M.list = {
    {
        name = GLOBAL.SERVICE_NAME.DATAMONGO,
        module = "db.datamongo",
    },
    {
        name = GLOBAL.SERVICE_NAME.LOGICPROXY,
        module = "clientproxy",
        path = "config.proxy.logic",
    },
    {
        name = GLOBAL.SERVICE_NAME.GAMEPROXY,
        module = "clientproxy",
        path = "config.proxy.center",
    },
}

return M
