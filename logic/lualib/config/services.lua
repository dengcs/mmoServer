local M = {}

M.list = {
     {
         name = GLOBAL.SERVICE_NAME.DATAMONGOD,
         module = "db.datamongod",
     },
     {
         name = GLOBAL.SERVICE_NAME.USERCENTERD,
         module = "usercenterd",
     },
}

return M
