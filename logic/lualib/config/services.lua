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
