local M = {}

M.list = {
     {
         name = GLOBAL.SERVICE_NAME.DATABASED,
         module = "db.databased",
         unique = true,
     },
     {
         name = GLOBAL.SERVICE_NAME.DATACACHED,
         module = "db.datacached",
         unique = true,
     },
}

return M
