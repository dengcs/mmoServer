local M = {}

M.list = {
    {
        name    = GLOBAL.SERVICE_NAME.DATAMONGO,
        module  = "db.datamongo",
    },

    {
        name    = GLOBAL.SERVICE_NAME.GATE,
        module  = "client.gate",
        port    = 50001,
        maxclient = 100,
    },
}

return M
