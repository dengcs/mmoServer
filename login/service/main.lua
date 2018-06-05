local skynet = require "skynet_ex"
local cluster = require "skynet.cluster"

skynet.start(function()
  skynet.error("Server start")
  skynet.newservice("debug_console",8800)

  -- 启动公共服务
  local services = require("config.services")
  local summdriver = skynet.summdriver()
  summdriver.start()
  summdriver.autoload(services.summ)
 
  cluster.open "login"
  
  skynet.error("Server end")
  skynet.exit()
end)