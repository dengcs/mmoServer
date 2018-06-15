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

  local userdriver = skynet.userdriver()
--  local sql = string.format("INSERT %s(uid, data) VALUES(%s,'%s') ON DUPLICATE KEY UPDATE data = '%s'", "account", 1001, "dcs---test", "dcs---test-new")
--  userdriver.db_insert("test", sql)
--
  local udata = {
    uid      = "1001",
    nickname = "dcstest",
    portrait = "1",
    sex      = 1,
    experience = 1000,
    level    = 1
  }
  userdriver.dc_set(10,"1001",skynet.packstring(udata))
--  userdriver.dc_set(11,"1001","dcs---redis11")
--  
--  userdriver.dc_del(10,"1001")
--  userdriver.dc_del(11,"1001")

  local gated = skynet.newservice("client/gated", "0.0.0.0", 51001)
  skynet.name(GLOBAL.SERVICE_NAME.GATED,gated)
  
  --skynet.newservice("testproto")

  cluster.open "logic"
  
  skynet.error("Server end")
  skynet.exit()
end)