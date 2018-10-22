local nova = require "nova"
local service = require "service"

local CMD = {}

-- 禁言用户
local ban_users = {}
local dirty = false

-- 加载禁言信息
local function load_ban_data()
    local _, data = nova.call(GAME.SERVICE.KVCACHED, "lua", "get", "kvcached.chat.ban")
    if data ~= nil then
        ban_users = data
    end
end

-- 保存禁言信息
local function save_ban_data()
    nova.send(GAME.SERVICE.KVCACHED, "lua", "set", "kvcached.chat.ban", ban_users)
end

-- 定时器间隔(秒)
local interval = 60

-- 定时任务
local function on_timer()
    if dirty then
        save_ban_data()
        dirty = false
    end
    
	-- 重置定时器
	this.schedule(on_timer, interval, 1)
end


local function init_handler()
    load_ban_data()
    on_timer()
end

local function exit_handler()
    this.unschedule_all()
    
    if dirty then
        dirty = false
        save_ban_data()
    end
end

-- 新用户
function CMD.send_msg_to_world(uid, content)
    local now = os.time()
    if ban_users[uid] then
        if ban_users[uid].end_time then
            if ban_users[uid].end_time > now then
                LOG_DEBUG("uid[%s] is baned", uid)
                return
            else
                ban_users[uid] = nil
            end
        else
            LOG_DEBUG("uid[%s] is forever baned", uid)
            return
        end
    end
    nova.send(GAME.SERVICE.ONLINED, "lua", "broadcast", "chat_msg_notify", content)
end

-- 禁言用户
function CMD.ban_user(uids, end_time, forever)
    for _, v in pairs(uids) do
        ban_users[v] = {end_time = end_time, forever = forever}
    end
    dirty = true
end

-- 服务注册

local handler = {}

-- 消息分发逻辑
-- 1. 消息来源
-- 2. 消息类型
-- 3. 消息内容
function handler.command_handler(source, cmd, ...)
	local fn = CMD[cmd]
	if fn then
		return fn(source, ...)
	else
		ERROR("svcmanager : command[%s] can't find!!!", cmd)
	end
end

handler.init_handler = init_handler
handler.exit_handler = exit_handler

service.start(handler)