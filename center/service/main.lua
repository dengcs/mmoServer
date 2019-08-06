local skynet = require "skynet_ex"
local cluster = require "skynet.cluster"

skynet.start(function()
  skynet.error("Server start")
  skynet.newservice("debug_console",42001)
  
  -- 启动公共服务
  local services = require("config.services")
  local summdriver = skynet.summdriver()
  summdriver.start()
  summdriver.autoload(services.list)

  local gated = skynet.newservice("client/gate")
  skynet.name(GLOBAL.SERVICE_NAME.GATE,gated)
  skynet.call(gated, "lua", "open", {
    port = 52001,
    maxclient = 100,
    nodelay = false,
  })
  
  cluster.open(skynet.getenv("node"))
  
  skynet.error("Server end")
  skynet.exit()
end)