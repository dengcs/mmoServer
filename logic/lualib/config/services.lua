local skynet   = require "skynet"

local M = {}

M.summ = {
     {
         name = GLOBAL.SERVICE_NAME.DATABASED,
         master = GLOBAL.MASTER_TYPE.SUMMD,
         proto = GLOBAL.PROTO_TYPE.TERMINAL,
         module = "db.databased",
         unique = true,
     },
     {
         name = GLOBAL.SERVICE_NAME.DATACACHED,
         master = GLOBAL.MASTER_TYPE.SUMMD,
         proto = GLOBAL.PROTO_TYPE.TERMINAL,
         module = "db.datacached",
         unique = true,
     },
     {
         name = GLOBAL.SERVICE_NAME.PBD,
         master = GLOBAL.MASTER_TYPE.SUMMD,
         proto = GLOBAL.PROTO_TYPE.TERMINAL,
         module = "pbd",
         unique = true,
     },
     {
         name = GLOBAL.SERVICE_NAME.HANDSHAKE,
         master = GLOBAL.MASTER_TYPE.SUMMD,
         proto = GLOBAL.PROTO_TYPE.TERMINAL,
         module = "handshake",
         unique = true,
     },
}

return M
