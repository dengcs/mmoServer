local skynet = require "skynet_ex"
local cluster = require "skynet.cluster"
local spconf = require "config.spconf"
local hibernaloader = require "data.hibernaloader"

skynet.start(function()
  skynet.error("Server start")
  skynet.newservice("debug_console",41001)

  hibernaloader.register(spconf)
  
  -- 启动公共服务
  local services = require("config.services")
  local summdriver = skynet.summdriver()
  summdriver.start()
  summdriver.autoload(services.summ)

  local gated = skynet.newservice("client/gated", "0.0.0.0", 51001)
  skynet.name(GLOBAL.SERVICE_NAME.GATED,gated)
  
  -- 启动控制后台
  local cmd = skynet.newservice("httpd", "logic.cmd", 1)
  skynet.call(cmd, "lua", "init", {
    address = "0.0.0.0",
    port    = 41002,
    auto    = true,
    router  = { "router.cmd" },
  })

  cluster.open "logic"
  
  skynet.error("Server end")
  skynet.exit()
end)