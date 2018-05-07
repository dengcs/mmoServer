local skynet = require "skynet.manager"

local userdriver = require "driver.userdriver"
local summdriver = require "driver.summdriver"

function skynet.summdriver()
  return summdriver
end

function skynet.userdriver()
  return userdriver
end

return skynet