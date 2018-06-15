local parser = require "sprotoparser"
local sprotoloader = require "sprotoloader"

local loader = {}

-- 加载数据序列化协议
local function __fin(path, file)
    local filename = path .. file .. ".sp"
    local f = assert(io.open(filename), "Can't open sproto file")
    local data = f:read("a")
    f:close()
    return data
end

-- 加载数据序列化协议
local function __flistin(path, filelist)
    local stream = ""
    for _, file in pairs(filelist) do
        local data = __fin(path, file)
        stream = stream .. data
    end

    return stream
end

-- 注册数据序列化协议
function loader.register(conf)
    local data
    if type(conf.file) == "table" then
        data = __flistin(conf.path, conf.file)
    else
        data = __fin(conf.path, conf.file)
    end
    -- 注册数据序列化协议
    local sp = parser.parse(data)
    sprotoloader.save(sp,0)
end

function loader.save(bin, index)
    sprotoloader.save(bin, index)
end

function loader.load(index)
    return sprotoloader.load(index)
end

return loader
