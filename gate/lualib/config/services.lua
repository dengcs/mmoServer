local M = {}

M.list = {
    {
        name = GLOBAL.SERVICE_NAME.DATAMONGO,
        module = "db.datamongod",
        unique = true,
    },
    {
        name = GLOBAL.SERVICE_NAME.LOGICPROXY,
        module = "clientproxy",
        ip = "127.0.0.1",
        port = 51001,
    },
    {
        name = GLOBAL.SERVICE_NAME.GAMEPROXY,
        module = "clientproxy",
        ip = "127.0.0.1",
        port = 52001,
    },
}

return M
