-- 角色数据集合（用于社交的相关数据）
local skynet = require "skynet"
local nova = require "nova"
local SocialUser = class("SocialUser")

-- 角色社交数据模型
function SocialUser:ctor(uid)
    self.uid               = uid
    self.roomid            = 0
    self.need_save_flag    = false          -- 数据脏标记
    -- 登入时间戳
    self.last_login_time   = 0
    -- 登出时间戳
    self.last_logout_time  = 0
    -- 开始游戏的时间戳
    self.start_game_time   = 0
    -- 免打扰标识
    self.undisturb         = 0
    -- 当前段位
    self.curstage          = -1
    -- 在线标识
    self.online            = false
    self.charts_data       = {}             -- 排行需要数据
    self.common_car_id     = 0
    self.common_copilot_id = 0
    self.common_paint_id   = 0
    --车队UID
    self.tong_uid          = ""
    self.tong_name         = ""
    self.tong_job          = 0
end

-- 设置需要保存
function SocialUser:set_need_save()
    self.need_save_flag = true
end

-- 清除保存标识
function SocialUser:clear_save()
    self.need_save_flag = false
end

-- 是否需要保存
function SocialUser:is_need_save()
    return self.need_save_flag
end

-- 反序列化
function SocialUser:un_serialize(data)
    local social_data = skynet.unpack(data)
    self:init_data(social_data)
end

-- 序列化
function SocialUser:serialize()
    local data = self:get_user_data()
    local res = skynet.packstring(data)
    return res
end

function SocialUser:init_data(data)
    self.portrait = data.portrait
    self.level = data.level
    self.sex = data.sex
    self.nickname = data.nickname
    self.licence = data.licence
    self.undisturb = data.undisturb
    self.curstage = data.curstage
    if data.charts_data then
        if IS_TABLE(data.charts_data) then
            self.charts_data = data.charts_data
        end
    end
    self.common_car_id = data.common_car_id or 0
    self.common_copilot_id = data.common_copilot_id or 0
    self.common_paint_id = data.common_paint_id or 0
    self.portrait_box_id = data.portrait_box_id or 0
    self.signature = data.signature or ""
    self.vip_level = data.vip_level or 0
    self.tong_uid = data.tong_uid or ""
    self.tong_name = data.tong_name or ""
    self.tong_job = data.tong_job or 0
end

-- 获取数据（需要保存部分数据）
function SocialUser:get_user_data()
    local data =
    {
        uid = self.uid,
        portrait = self.portrait,
        level = self.level,
        sex	  = self.sex,
        nickname = self.nickname,
        licence = self.licence,
        undisturb = self.undisturb,
        curstage  = self.curstage,
        charts_data = self.charts_data,
        common_car_id = self.common_car_id,
        common_copilot_id = self.common_copilot_id,
        common_paint_id = self.common_paint_id,
        portrait_box_id = self.portrait_box_id,
        signature = self.signature,
        vip_level = self.vip_level,
        tong_uid = self.tong_uid,
        tong_name = self.tong_name,
        tong_job = self.tong_job,
    }
    return data
end

-- 转成好友数据
function SocialUser:get_user_friend_data()
    local data = {
        uid = self.uid,
        shared_role = self:get_user_shared_data(),
    }
    return data
end

-- 转成排行数据
function SocialUser:get_user_rank_data()
    local data = {
        uid = self.uid,
        nickname = self.nickname,
        level = self.level,
        portrait = self.portrait,
        curstage = self.curstage,
        common_car_id = self.common_car_id,
        common_copilot_id = self.common_copilot_id,
        common_paint_id = self.common_paint_id,
        portrait_box_id = self.portrait_box_id,
        vip_level = self.vip_level,
    }

    return data
end

-- 转成共享数据
function SocialUser:get_user_shared_data()
    local data = {
        uid = self.uid,
        nickname = self.nickname,
        level = self.level,
        sex   = self.sex,
        licence = self.licence,
        portrait = self.portrait,
        leving_time = 0,
        roomid = self.roomid,
        undisturb = self.undisturb,
        curstage  = self.curstage,
        portrait_box_id = self.portrait_box_id,
        signature = self.signature,
        vip_level = self.vip_level,
        tong_uid = self.tong_uid,
        tong_name = self.tong_name,
        tong_job = self.tong_job,
    }
    if self.online then
        if self.start_game_time == 0 then
            data.leving_time = 0
        else
            local now = math.floor(skynet.time())
            data.leving_time = math.max(1, now - self.start_game_time) --比赛开始时间至少1秒
        end
    else
        data.leving_time = -1
        data.last_logout_time = self.last_logout_time
    end
    return data
end

-- 刷新数据
function SocialUser:update_data(data)
    local friend_data_changed = false
    if data.portrait and self.portrait ~= data.portrait then
        self.portrait = data.portrait
        friend_data_changed = true
    end

    if data.level and self.level ~= data.level then
        self.level = data.level
        friend_data_changed = true
    end

    if data.sex and self.sex ~= data.sex then
        self.sex = data.sex
        friend_data_changed = true
    end

    if data.nickname and self.nickname ~= data.nickname then
        self.nickname = data.nickname
        friend_data_changed = true
    end

    if data.licence and self.licence ~= data.licence then
        self.licence = data.licence
        friend_data_changed = true
    end

    if data.roomid and self.roomid ~= data.roomid then
        self.roomid = data.roomid
        friend_data_changed = true
    end

    if data.state and self.state ~= data.state then
        self.state = data.state
    end

    if data.scene and self.scene ~= data.scene then
        self.scene = data.scene
    end

    if data.change_time and self.change_time ~= data.change_time then
        self.change_time = data.change_time
    end

    if data.online ~= nil and self.online ~= data.online then
        self.online = data.online
        friend_data_changed = true
    end

    if data.last_login_time and self.last_login_time ~= data.last_login_time then
        self.last_login_time = data.last_login_time
        friend_data_changed = true
    end

    if data.last_logout_time and self.last_logout_time ~= data.last_logout_time then
        self.last_logout_time = data.last_logout_time
        friend_data_changed = true
    end

    if data.start_game_time and self.start_game_time ~= data.start_game_time then
        self.start_game_time = data.start_game_time
        friend_data_changed = true
    end

    if data.undisturb and self.undisturb ~= data.undisturb then
        self.undisturb = data.undisturb
        friend_data_changed = true
    end

    if data.curstage and self.curstage ~= data.curstage then
        self.curstage = data.curstage
        friend_data_changed = true
    end

    if data.charts_data then
        for k, v in pairs(data.charts_data) do
            if self.charts_data[k] ~= v then
                self.charts_data[k] = v
            end
        end
    end

    if data.portrait_box_id and self.portrait_box_id ~= data.portrait_box_id then
        self.portrait_box_id = data.portrait_box_id
        friend_data_changed = true
    end

    if data.signature and self.signature ~= data.signature then
        self.signature = data.signature
        friend_data_changed = true
    end

    if data.vip_level and self.vip_level ~= data.vip_level then
        self.vip_level = data.vip_level
        friend_data_changed = true
    end

    if data.common_car_id and self.common_car_id ~= data.common_car_id then
        self.common_car_id = data.common_car_id
        friend_data_changed = true
    end
    if data.common_copilot_id and self.common_copilot_id ~= data.common_copilot_id then
        self.common_copilot_id = data.common_copilot_id
        friend_data_changed = true
    end
    if data.common_paint_id and self.common_paint_id ~= data.common_paint_id then
        self.common_paint_id = data.common_paint_id
        friend_data_changed = true
    end

    if data.tong_uid and self.tong_uid ~= data.tong_uid then
        self.tong_uid = data.tong_uid
        friend_data_changed = true
    end
    if data.tong_name and self.tong_name ~= data.tong_name then
        self.tong_name = data.tong_name
        friend_data_changed = true
    end
    if data.tong_job and self.tong_job ~= data.tong_job then
        self.tong_job = data.tong_job
        friend_data_changed = true
    end

    self:set_need_save()
    return friend_data_changed
end

-- 清空排行数据
function SocialUser:clear_charts_data(charts_id)
    if self.charts_data[charts_id] then
        self.charts_data[charts_id] = 0
        self:set_need_save()
    end
end

return SocialUser
