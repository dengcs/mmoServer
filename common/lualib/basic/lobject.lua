function class(cname, super)
    if type(super) ~= "table" then
        super = nil
    end
    local clazz = {}
    clazz.__cname = cname
    clazz.__index = clazz
    if super then
        clazz.super = super
        setmetatable(clazz, {__index = super})
    else
        clazz.ctor = function() end
    end
    function clazz.new(...)
        local instance = setmetatable({}, clazz)
        instance.class = clazz
        instance:ctor(...)
        return instance
    end
    return clazz
end