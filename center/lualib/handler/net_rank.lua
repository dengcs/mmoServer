---------------------------------------------------------------------
--- 排行榜模块相关业务逻辑
---------------------------------------------------------------------
local skynet = require "skynet"
local social = require "social"

---------------------------------------------------------------------
--- 内部变量/内部逻辑
---------------------------------------------------------------------

local function load_social_data(rank)
    if rank then
        local uData = social.get_user_data(rank.pid)
        if uData then
            rank.sex        = uData.sex
            rank.nickname   = uData.nickname
            rank.portrait   = uData.portrait
        end
    end
end

---------------------------------------------------------------------
--- 内部指令处理逻辑
---------------------------------------------------------------------
local command = {}

---------------------------------------------------------------------
--- 网络请求处理逻辑
---------------------------------------------------------------------
local request = {}

-- 请求邮箱数据
function request:rank_access()
    local pid       = self.user.pid
    local alias     = self.proto.alias
    local spoint    = self.proto.spoint
    local epoint    = self.proto.epoint
    local msg_data = { alias = alias }

    repeat
        local ok, ranks = skynet.call(GLOBAL.SERVICE_NAME.RANK, "lua", "range_byrank", alias, spoint, epoint)
        if ok ~= 0 then
            break
        end

        for _,rank in pairs(ranks or {}) do
            load_social_data(rank)
        end

        msg_data.ranks = ranks

        local ok, myrank = skynet.call(GLOBAL.SERVICE_NAME.RANK, "lua", "rank", alias, pid)
        if ok ~= 0 then
            break
        end

        if myrank then
            load_social_data(myrank)
            msg_data.myrank = myrank
        end
    until(true)

    self.response("rank_access_resp", msg_data)
end

---------------------------------------------------------------------
--- 内部事件处理逻辑
---------------------------------------------------------------------
local trigger = {}

-- 导出脚本模块
return { COMMAND = command, REQUEST = request, TRIGGER = trigger }
