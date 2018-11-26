local skynet = require "skynet_ex"

skynet.start(function()
  skynet.error("Server start")
  skynet.newservice("debug_console",40001)

  -- 启动公共服务
  local services = require("config.services")
  local summdriver = skynet.summdriver()
  summdriver.start()
  summdriver.autoload(services.list)
  
  local gated = skynet.newservice("client/gated", "0.0.0.0", 50001)
  skynet.name(GLOBAL.SERVICE_NAME.GATED,gated)
  
  skynet.error("Server end")
  skynet.exit()
end)