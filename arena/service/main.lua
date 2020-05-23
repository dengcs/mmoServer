local skynet = require "skynet_ex"
local cluster = require "skynet.cluster"

skynet.start(function()
  skynet.error("Server start")
  skynet.newservice("debug_console",43001)
  
  -- 启动公共服务
  local services = require("config.services")
  local summdriver = skynet.summdriver()
  summdriver.start()
  summdriver.autoload(services.list)

  local gated = skynet.newservice("client/gate")
  skynet.name(GLOBAL.SERVICE_NAME.GATE,gated)
  skynet.call(gated, "lua", "open", {
    port = 53001,
    maxclient = 100,
    nodelay = false,
  })

  -- 启动控制后台
  local cmd = skynet.newservice("http", "arena.cmd", 1)
  skynet.call(cmd, "lua", "init", {
    address = "0.0.0.0",
    port    = 43002,
    auto    = true,
    router  = { "router.cmd" },
  })
  
  cluster.open(skynet.getenv("node"))
  
  skynet.error("Server end")
  skynet.exit()
end)