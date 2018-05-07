local skynet = require "skynet"
local netpack = require "skynet.netpack"
local sprotoloader = require "sprotoloader"

local max_client = 64

local __MAX_TABLE_DEPTH = 3

local function __dump_tab(depth)
    local buffer = ""
    for n = 1, depth do
        buffer = buffer .. "\t"
    end
    return buffer
end

local function __dump_table(t, depth)
    local tp = type(t)
    local buffer = ""
    if tp == "table" then
        local dt = depth + 1
        if dt > __MAX_TABLE_DEPTH then
            buffer = buffer .. "..."
            return buffer
        end

        buffer = buffer .. "{\n"
        depth = depth + 1
        for k, v in pairs(t) do
            buffer = buffer .. __dump_tab(depth) .. tostring(k) .. " = "
            if type(v) == "table" then
                buffer = buffer .. __dump_table(v, depth)
            else
                buffer = buffer .. tostring(v)
            end

            if depth ~= 0 then
                buffer = buffer .. ","
            end
            buffer = buffer .. "\n"
        end

        depth = depth - 1
        buffer = buffer .. __dump_tab(depth) .. "}"
    else
        buffer = buffer .. tostring(t)
    end
    return buffer
end

table.tostring = function (t)
    if type(t) ~= "table" then
        return "UNKNOWN"
    end
    return __dump_table(t, 0)
end

local function test()
  local data = {a="dcs1",b="dcs2"}
  local tmp = skynet.packstring(data)
  local packdata,datasize = netpack.pack(tmp)
  print("dcs1--"..type(packdata))
  local unpackdata = skynet.tostring(packdata,datasize)
  unpackdata = unpackdata:sub(3)
  print("dcs2--"..table.tostring(skynet.unpack(unpackdata)))
end

skynet.start(function()
	skynet.error("Server start")
	skynet.uniqueservice("protoloader")
	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end
	skynet.newservice("debug_console",8000)
	skynet.newservice("simpledb")
	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", {
		port = 8899,
		maxclient = max_client,
		nodelay = true,
	})
	skynet.newservice("testredis")
	skynet.exit()
end)
