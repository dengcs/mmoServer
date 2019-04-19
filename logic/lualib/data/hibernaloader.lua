local lfs      		= require "lfs"
local skynet        = require "skynet"
local parser        = require "sprotoparser"
local sprotoloader  = require "sprotoloader"

local pairs     = pairs
local assert    = assert
local strfmt    = string.format
local tinsert   = table.insert

local loader = {}

-- 遍历指定目录（递归）
-- 1. 目录路径
-- 2. 文件后缀
-- 3. 文件集合
local function traverse(root, suffix, collect)
    collect = collect or {}
    for element in lfs.dir(root) do
        if (element ~= ".") and (element ~= "..") then
            local path = strfmt("%s/%s", root, element)
            local attr = lfs.attributes(path)
            if attr.mode == "directory" then
                traverse(path, suffix, collect)
            else
                if (suffix == nil) or (suffix == path:match(".+%.(%w+)$")) then
                    tinsert(collect, path)
                end
            end
        end
    end
    return collect
end

-- 加载数据序列化协议
local function fstream(filename)
    local f = assert(io.open(filename), "Can't open sproto file")
    local data = f:read("a")
    f:close()
    return data
end

-- 注册数据序列化协议
function loader.register(conf)
    local data = ""

    local node  = assert(skynet.getenv("node"),"getenv获取不到node值！")
    local root  = strfmt("./%s/lualib/model", node)
    local files = traverse(root, "sp")

    for _,file in pairs(files or {}) do
        local stream = fstream(file)
        data = data .. stream
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
