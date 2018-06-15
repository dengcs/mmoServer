local parser = require "sprotoparser"
local core = require "sproto.core"
local sproto = require "sproto"

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
    local sp = core.newproto(parser.parse(data))
    core.saveproto(sp, 0)
end

function loader.save(bin, index)
    local sp = core.newproto(bin)
    core.saveproto(sp, index)
end

function loader.load(index)
    local sp = core.loadproto(index)
    -- no __gc in metatable
    return sproto.sharenew(sp)
end

return loader
