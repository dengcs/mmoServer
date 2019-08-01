local M = {}

M.list = {
     {
         name = GLOBAL.SERVICE_NAME.DATAMONGO,
         module = "db.datamongod",
     },
     {
         name = GLOBAL.SERVICE_NAME.USERCENTER,
         module = "usercenterd",
     },
}

return M
