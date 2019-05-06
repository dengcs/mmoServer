function class(cname, super)
    local clazz = {}
    clazz.__cname = cname
    if super then
        clazz.super = super
        setmetatable(clazz, {__index = super})
    else
        clazz.ctor = nil
    end
    function clazz.new(...)
        local instance = setmetatable({}, {__index = clazz})
        instance:ctor(...)
        return instance
    end
    return clazz
end