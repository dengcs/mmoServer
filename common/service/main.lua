local skynet = require "skynet_ex"

skynet.start(function()
  skynet.error("Server start")
  skynet.newservice("debug_console",8000)

  local gated = skynet.newservice("client/gate")
  skynet.name(GLOBAL.SERVICE_NAME.GATE,gated)

  skynet.error("Server end")
  skynet.exit()
end)