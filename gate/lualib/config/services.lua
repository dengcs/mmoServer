local M = {}

M.list = {
    {
        name = GLOBAL.SERVICE_NAME.DATAMONGOD,
        module = "db.datamongod",
        unique = true,
    },
    {
        name = GLOBAL.SERVICE_NAME.LOGICPROXY,
        module = "logicproxy",
        unique = true,
        ip = "127.0.0.1",
        port = 51001,
    },
}

return M
