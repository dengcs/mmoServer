local skynet = require "skynet_ex"

skynet.start(function()
  skynet.error("Server start")
  skynet.newservice("debug_console",8000)

  -- 启动公共服务
--  local services = require("config.services")
--  local summdriver = skynet.summdriver()
--  summdriver.start()
--  summdriver.autoload(services.summ)

--  local userdriver = skynet.userdriver()
--  local sql = string.format("INSERT %s(uid, data) VALUES(%s,'%s') ON DUPLICATE KEY UPDATE data = '%s'", "account", 1001, "dcs---test", "dcs---test-new")
--  userdriver.db_insert("test", sql)
--  
--  userdriver.dc_set(10,"1001","dcs---redis10")
--  userdriver.dc_set(11,"1001","dcs---redis11")
--  
--  userdriver.dc_del(10,"1001")
--  userdriver.dc_del(11,"1001")

  local gated = skynet.newservice("client/gate")
  skynet.name(GLOBAL.SERVICE_NAME.GATE,gated)

  skynet.error("Server end")
  skynet.exit()
end)