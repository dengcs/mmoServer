---------------------------------------------------------------------
--- 聊天系统服务
---------------------------------------------------------------------
local service  = require "factory.service"
local skynet   = require "skynet"

---------------------------------------------------------------------
--- 内部变量/内部逻辑
---------------------------------------------------------------------

-- 在线用户列表
local users = nil
-- 频道数组
local channels = nil
--自定义频道 生产唯一cid，控制参数
--频道两个参数：cid-频道唯一id，ctype-频道类型
--cid为1-10频道，cid==ctype
local __cid = 100
-----------------------------------------------------------
--- 队员数据模型
-----------------------------------------------------------
local User = class("user")

-- 构造模型实例
-- 1. 角色数据 pid
function User:ctor(pid)
    self.pid    = pid
    self.cids = {}
end

-- 登录时，刷新数据
function User:update(pid)
    if self.pid ~= pid then
        LOG_ERROR("[chatd] User:update pid error! pid=%s,self.pid=%s",pid,self.pid)
        self.pid = pid
    end
end

-- 进入频道，专门供channel调用
function User:enter(cid)
    if self.cids[cid] then
        -- LOG_DEBUG("[chatd] User:enter user already enter channel. pid=%s,cid=%s",self.pid,cid)
    else
        self.cids[cid] = cid
    end
end

-- 退出频道，专门供channel调用
function User:exit(cid)
    if self.cids[cid] then
        self.cids[cid] = nil
    else
        LOG_DEBUG("[chatd] User:exit user no in channel. pid=%s,cid=%s",self.pid,cid)
    end
end

-- 下发通知消息
-- 1. 消息名称
-- 2. 消息内容
function User:response(name, data)
    this.usersend(self.pid, "response_message", name, data)
end

-- 通过类型获取频道，用户在一种频道上只能拥有一个
-- 1. 频道类型
function User:get_channel_by_type(ctype)
    local channel, cur_channel
    for _,cid in pairs(self.cids) do
        channel = channels[cid]
        if channel then
            if channel.ctype == ctype then
                assert(cur_channel == nil)
                cur_channel = channel
            end
        else
            self.cids[cid] = nil
        end
    end
    return cur_channel
end

-- 广播用户的加入的某种频道
-- 1. 频道类型
-- 2. 协议名
-- 3.协议结构体
function User:broadcast(ctype, name, data)
    local cur_channel = nil
    for _,cid in pairs(self.cids) do
        if channels[cid] and channels[cid].ctype then
            assert(cur_channel == nil)
            cur_channel = channels[cid]
        end
    end
    if cur_channel then
        cur_channel:broadcast(name, data)
    end
end

--玩家登陆时，推送最近10条聊天记录
function User:access_msgs()
    local ctypes = {GAME.CHAT.CHANNEL.WORLD,GAME.CHAT.CHANNEL.CLUB}
    local channel, chat_msgs
    for _,ctype in ipairs(ctypes) do
        -- LOG_DEBUG("User:access_msgs ctype=%s",ctype)
        channel = self:get_channel_by_type(ctype)
        if channel then
            chat_msgs = channel:get_chat_msgs()
            if chat_msgs then
                -- LOG_DEBUG("User:access_msgs channel=%s #chat_msgs=%s",channel,#chat_msgs)
                for _,chat_msg in ipairs(chat_msgs) do
                    self:response(chat_msg.name, chat_msg.data)
                end
            end
        end
    end
end

-- function User:tostring()
--     return "User:pid="..self.pid..",cids="..table.tostring(self.cids)
-- end

-----------------------------------------------------------
--- 频道数据模型
-----------------------------------------------------------
local Channel = class("channel")

-- 构建实例
-- 1.频道id
function Channel:ctor(cid,ctype)
    self.cid = assert(cid)
    self.ctype = assert(ctype)
    self.users = {}     -- 用户列表
end

function Channel:push_chat_msg(chat_msg)
    self.chat_msgs = self.chat_msgs or {}
    table.insert(self.chat_msgs,chat_msg)

    local ChatMessageMaxOffline = this.sheetdata("ConfigBaseData", "ChatMessageMaxOffline", "Data")
    -- LOG_DEBUG("Channel:push_chat_msg #self.chat_msgs=%s ChatMessageMaxOffline=%s",#self.chat_msgs,ChatMessageMaxOffline)
    while #self.chat_msgs > ChatMessageMaxOffline do
        table.remove(self.chat_msgs,1)
    end
end

function Channel:get_chat_msgs()
    return self.chat_msgs
end

--用户进入频道
function Channel:enter_user(user)
    -- if self.users[user.pid] then
    --     LOG_DEBUG("[chatd] Channel:enter_user user is exist!!  user.pid=%s",user.pid)
    -- end
    self.users[user.pid] = user
    user:enter(self.cid)
end

--用户退出频道
function Channel:exit_user(pid)
    local user = self.users[pid]
    if user then
        self.users[pid] = nil
        user:exit(self.cid)
        -- else
        -- LOG_DEBUG("[chatd] Channel:exit_user user not in Channel!!  pid=%s",pid)
    end
    --除了世界频道，空频道都进行清理
    if next(self.users) == nil then
        --低于100固定频道不能删除
        if self.cid > 100 then
            channels[self.cid] = nil
        end
    end
end

--频道退出
function Channel:on_exit()
    for _,user in pairs(self.users) do
        user:exit(self.cid)
    end
end

-- 频道广播
-- 1. 消息名称
-- 2. 消息内容
function Channel:broadcast(name, data)
    --社团消息需要缓存10条（策划需求）
    if self.ctype == GAME.CHAT.CHANNEL.CLUB then
        self:push_chat_msg({name=name,data=data})
    end
    for pid in pairs(self.users) do
        this.usersend(pid, "response_message", name, data)
    end
end

-- 全服广播,只有全服频道才可使用世界广播
-- 1. 消息名称
-- 2. 消息内容
function Channel:rbroadcast(name, data)
    assert(GAME.CHAT.CHANNEL.SERVERS == self.ctype)
    skynet.send(GLOBAL.SERVICE.USERCENTERD, "lua", "broadcast","response_message", name, data)
end

-- 世界广播,只有世界频道才可使用世界广播
-- 1. 消息名称
-- 2. 消息内容
function Channel:wbroadcast(name, data)
    assert(GAME.CHAT.CHANNEL.WORLD == self.ctype)
    --世界消息需要缓存10条（策划需求）
    self:push_chat_msg({name=name,data=data})
    skynet.send(GLOBAL.SERVICE.USERCENTERD, "lua", "broadcast","response_message", name, data)
end

--打印信息，调试使用
function Channel:tostring()
    local logs = {}
    for _,user in pairs(self.users) do
        table.insert(logs,user:tostring())
    end
    local logs_txt = table.concat(logs,"\n")
    return "Channel:cid="..self.cid..",users="..logs_txt
end

function __create_channel(ctype)
    local cid = __cid
    __cid = __cid+1
    local channel = Channel.new(cid,ctype)
    channels[channel.cid] = channel
    return channel
end

---------------------------------------------------------------------
--- 服务导出业务接口
---------------------------------------------------------------------
local command = {}

-- 角色上线登录
-- 1. 指令来源
-- 2. 角色编号
function command.on_login(source, pid)
    assert(pid>0,"[chatd]command.on_login pid is invalid!")
    local user = users[pid]
    if not user then
        user = User.new(pid)
        users[pid] = user
    end
    channels[GAME.CHAT.CHANNEL.WORLD]:enter_user(user)
end

-- 角色断线
-- 1. 指令来源
-- 2. 角色编号
function command.on_quit(source, pid)
    local user = users[pid]
    if not user then
        return
    end
    assert(user.pid == pid,"[chatd]command.on_quit pid is invalid!")
    users[pid] = nil
    for _,cid in pairs(user.cids) do
        if channels[cid] then
            channels[cid]:exit_user(pid)
        else
            LOG_INFO("[chatd] command.on_quit channel not exist! cid=%s",cid)
        end
    end
end

--创建频道
--1.频道类型
--2.创建时需要加入读玩家
function command.create_channel(source,ctype,pids)
    local channel = __create_channel(ctype)
    local user
    for _,pid in ipairs(pids) do
        user = users[pid]
        if user then
            channel:enter_user(user)
        else
            LOG_ERROR("[chatd] command.create_channel user never login server! pid=%s",pid)
        end
    end
    return channel.cid
end

function command.remove_channel(source,cid)
    local channel = channels[cid]
    if channel then
        channel:on_exit()
    else
        LOG_INFO("[chatd] command.remove_channel channel not exist! cid=%s",cid)
    end
end

-- 给特定频道广播客户端聊天数据
-- 1.serverid
-- 2.发送指定的频道
-- 3.proto名
-- 4.proto
-- 5.指定玩家的pid数组
function command.broadcast(source,schannel,proto_name, proto, pids)
    local ret = 0
    --发送到全服频道
    if schannel == GAME.CHAT.CHANNEL.SERVERS then
        channels[GAME.CHAT.CHANNEL.SERVERS]:rbroadcast(proto_name,proto)

        --发送到世界频道
    elseif schannel == GAME.CHAT.CHANNEL.WORLD then
        channels[GAME.CHAT.CHANNEL.WORLD]:wbroadcast(proto_name,proto)

        --发送到当前game节点
        -- elseif schannel == GAME.CHAT.CHANNEL.ROOM then
        -- channels[GAME.CHAT.CHANNEL.WORLD]:broadcast(proto_name,proto)
        --发送到私聊频道
    elseif schannel == GAME.CHAT.CHANNEL.PRIVATE
            or schannel == GAME.CHAT.CHANNEL.FRIEND then
        local sender = users[tonumber(proto.send_pid)]
        if sender then
            for _,pid in ipairs(pids) do
                this.usersend(pid, "response_message", proto_name, proto)
            end
        else
            ret = ERRCODE.CHAT_PLAYER_OFFLINE
        end
    else
        ret = ERRCODE.CHAT_CHANNEL_ERROR
    end
    return ret
end

--请求最近的聊天信息
function command.access_msgs(source, pid)
    -- LOG_DEBUG("command.access_msgs source, pid=%s",pid)
    local user = users[pid]
    if not user then
        return ERRCODE.CHAT_PLAYER_OFFLINE
    end
    user:access_msgs(source)
    return 0
end

---------------------------------------------------------------------
--- 服务事件回调（底层事件通知）
---------------------------------------------------------------------
local server = {}

-- 服务构造通知
-- 1. 构造参数
function server.on_init(config)
    assert(not channels)
    users = {}
    channels = {
        [GAME.CHAT.CHANNEL.SERVERS] = Channel.new(GAME.CHAT.CHANNEL.SERVERS,GAME.CHAT.CHANNEL.SERVERS),
        [GAME.CHAT.CHANNEL.WORLD] = Channel.new(GAME.CHAT.CHANNEL.WORLD,GAME.CHAT.CHANNEL.WORLD)
    }
end

-- 服务停止通知
function server.on_stop()
    assert(false, "chatd : no on_stop")
end

-- 服务退出通知
function server.on_exit()
    assert(false, "chatd : no on_exit")
end

-- 网络消息通知
-- 1. 套接字
-- 2. 消息内容
function server.on_message(fd, message)
    assert(false, "chatd : no on_message")
end

-- 业务指令调用
-- 1. 指令来源
-- 2. 指令名称
-- 3. 执行参数
function server.on_command(source, cmd, ...)
    local fn = command[cmd]
    if fn then
        return fn(source, ...)
    else
        ERROR("chatd : command[%s] not found!!!", cmd)
    end
end

-- 启动服务对象
service.start(server)




