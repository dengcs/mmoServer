local M = {}

M.list = {
     {
         name = GLOBAL.SERVICE_NAME.DATAMONGOD,
         module = "db.datamongod",
         unique = true,
     },
     {
         name = GLOBAL.SERVICE_NAME.USERCENTERD,
         module = "usercenterd",
         unique = true,
     },
}

return M
