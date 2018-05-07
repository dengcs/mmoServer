local CTYPE = {
    COBJECT = 1,
    LUA = 2,
}

function class(classname, super)
    local super_type = type(super)
    local cls

    if super_type ~= "function" and super_type ~= "table" then
        super = nil
        super_type = nil
    end

    if super_type == "function" or (super and super.__ctype == CTYPE.COBJECT) then
        -- inherited from native C++ object
        cls = {}

        if super_type == "table" then
            -- copy fields from super
            for k, v in pairs(super) do cls[k] = v end
            cls.__create = super.__create
            cls.super = super
        else
            cls.__create = super
            cls.ctor = function() end
        end

        cls.__cname = classname
        cls.__ctype = CTYPE.COBJECT

        function cls.new(...)
            local instance = cls.__create(...)
            -- copy fields from class to native object
            for k, v in pairs(cls) do instance[k] = v end
            instance.class = cls
            instance:ctor(...)
            return instance
        end
    else
        -- inherited from Lua object
        if super then
            cls = {}
            setmetatable(cls, { __index = super })
            cls.super = super
        else
            cls = { ctor = function() end }
        end

        cls.__cname = classname
        cls.__ctype = CTYPE.LUA -- lua
        cls.__index = cls

        function cls.new(...)
            local instance = setmetatable({}, cls)
            instance.class = cls
            instance:ctor(...)
            return instance
        end
    end

    return cls
end
