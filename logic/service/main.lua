local skynet        = require "skynet_ex"
local cluster       = require "skynet.cluster"
local hibernaloader = require "data.hibernaloader"

skynet.start(function()
  skynet.error("Server start")
  skynet.newservice("debug_console",41001)

  hibernaloader.register()
  
  -- 启动公共服务
  local services = require("config.services")
  local summdriver = skynet.summdriver()
  summdriver.start()
  summdriver.autoload(services.list)

  local gated = skynet.newservice("client/gate")
  skynet.name(GLOBAL.SERVICE_NAME.GATE,gated)
  skynet.call(gated, "lua", "open", {
    port = 51001,
    maxclient = 100,
    nodelay = false,
  })
  
  -- 启动控制后台
  local cmd = skynet.newservice("http", "logic.cmd", 1)
  skynet.call(cmd, "lua", "init", {
    address = "0.0.0.0",
    port    = 41002,
    auto    = true,
    router  = { "router.cmd" },
  })

  -- 开启集群
  local node      = skynet.getenv("node") or "logic"
  local node_id   = skynet.getenv("nodeid") or 101
  local node_name = node..node_id
  cluster.open(node_name)

  skynet.error("Server end")
  skynet.exit()
end)