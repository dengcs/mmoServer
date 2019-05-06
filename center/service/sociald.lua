local skynet    =   require "skynet"
local service   =   require "factory.service"

-----------------------------------------------------------
--- 内部類
-----------------------------------------------------------

-- 社交数据模型
local social = class("social")

function social:ctor()
    self.cache      = {}
    self.cache_max  = 1000
end

function social:get(pid)

end

function social:update(pid, data)

end

function social:save(pid)

end

function social:save_all()

end

-----------------------------------------------------------
--- 服务业务接口
-----------------------------------------------------------

local CMD = {}

-- 同步数据
function CMD.update_user(pid, data)
end

-- 保存数据
function CMD.save_user(pid)

end

-- 获取指定用户数据
function CMD.get_user_data(pid)
end

function CMD.search_pid_by_name(name)
end

-- 搜索玩家
function CMD.search_friend(name)
end

-- 获取pid包装成好友型的数据
function CMD.get_friend_data(pid)
end

-- 服务注册
local server = {}

-- 服务开启通知
-- 1. 构造参数
function server.init_handler(arguments)
end

-- 服务退出通知
function server.exit_handler()
end

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