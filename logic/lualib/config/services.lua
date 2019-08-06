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
}

return M
