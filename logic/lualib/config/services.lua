local skynet   = require "skynet"

local M = {}

M.summ = {
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
     {
         name = GLOBAL.SERVICE_NAME.USERCENTERD,
         module = "usercenterd",
         unique = true,
     },
     {
         name = GLOBAL.SERVICE_NAME.PBD,
         module = "pbd",
         unique = true,
     },
     {
         name = GLOBAL.SERVICE_NAME.GAME,
         module = "combat.instance.game",
         unique = true,
     },
     {
         name = GLOBAL.SERVICE_NAME.ROOM,
         module = "combat.room",
         unique = true,
     },
}

return M
