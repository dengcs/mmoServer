local skynet = require "skynet_ex"
local cluster = require "skynet.cluster"

skynet.start(function()
  skynet.error("Server start")
  skynet.newservice("debug_console",40001)

  -- 启动公共服务
  local services = require("config.services")
  local summdriver = skynet.summdriver()
  summdriver.start()
  summdriver.autoload(services.summ)
  
  local gated = skynet.newservice("client/gated", "0.0.0.0", 50001)
  skynet.name(GLOBAL.SERVICE_NAME.GATED,gated)
 
  cluster.open "login"
  
  local hand_sev = cluster.proxy("logic", GLOBAL.SERVICE_NAME.HANDSHAKE)
  skynet.name(GLOBAL.SERVICE_NAME.HANDSHAKE,hand_sev)
  
  skynet.error("Server end")
  skynet.exit()
end)