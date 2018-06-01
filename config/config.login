include "config.game.engine"
include "config.game.common"
include "config.game.login"

root = "./engine/"
luaservice = login_service..";"..common_service..";"..engine_service
lualoader = root .. "lualib/loader.lua"
lua_path = login_path..";"..common_path..";"..engine_path
lua_cpath = root .. "luaclib/?.so"

preload = "./common/lualib/preload.lua"	-- run preload.lua before every lua service run
thread = 8
logger = nil
logpath = "."
harbor = 0
start = "main"	-- main script
bootstrap = "snlua bootstrap"	-- The service for bootstrap
cpath = root.."cservice/?.so"
datasource = "config.datasource"


node = "login"