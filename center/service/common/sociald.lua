local skynet    =   require "skynet"
local service   =   require "factory.service"

-----------------------------------------------------------
--- 内部類
-----------------------------------------------------------

-- 社交数据模型
local udata = class("udata")

function udata:ctor(pid)
    self.pid = pid
end

function udata:serialize()
    return skynet.packstring(
            {
                nikename          = self.nikename,
            })
end

function udata:unserialize(data)
    if data then
        local vdata     = skynet.unpack(data)
        self.nikename   = vdata.nikename
    end
end

-----------------------------------------------------------
--- 社交缓存对象
-----------------------------------------------------------

-- 数据加载逻辑
-- 1. 数据键值
local function load(key)
    local udata = udata.new(key)
    local vdata = skynet.call(GLOBAL.SERVICE.DATACACHE, "lua", "get", "social", key)
    if vdata then
        udata:unserialize(vdata)
    end
    return udata
end

-- 数据移除逻辑
-- 1. 数据键值
-- 2. 数据内容
local function save(key, udata)
    if udata then
        if (udata:check_dirty()) then
            skynet.send(GLOBAL.SERVICE.DATACACHE, "lua", "set", "social", key, udata:serialize())
            udata:clear_dirty()
        end
    end
end

function dCache:ctor()
    self.queue = {}
end

function dCache:get(pid)
    local udata = self.queue[pid]
    if not udata then
        udata = load(pid)
        self.queue[pid] = udata
    end
    return udata
end

function dCache:clear()
    for i, v in pairs(self.queue) do
        save(i, v)
    end
end

-- 构建缓存对象
local cache = dCache.new()

-----------------------------------------------------------
--- 服务业务接口
-----------------------------------------------------------

local CMD = {}

-- 同步数据
function CMD.update_user(pid, data)
end

-- 搜索玩家
function CMD.search_friend(name)
end

-- 获取pid包装成好友型的数据
function CMD.get_friend_data(pid)
end

-- 获取指定用户数据
function CMD.get_user_data_by_pid(pid)
end

function CMD.search_pid_by_name(name)
end

-- 服务注册
local server = {}

-- 消息分发逻辑
-- 1. 消息来源
-- 2. 消息类型
-- 3. 消息内容
function server.command_handler(source, cmd, ...)
	local fn = CMD[cmd]
	if fn then
		return fn(...)
	else
		ERROR("svcmanager : command[%s] can't find!!!", cmd)
	end
end

service.start(server)