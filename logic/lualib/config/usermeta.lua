---------------------------------------------------------------------
--- 游戏角色数据描述
---------------------------------------------------------------------
local M = 
{
    Player = 
    {
        mode = GAME.COLLECTIONS.PLAYER,
        require    = {"model.player"},
        on_init    = "on_init",
    },
}
return M
