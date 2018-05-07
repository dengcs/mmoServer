local skynet = require "skynet"

local method = {}

function method.resolve(args)
    if not args then
        return nil
    else
        local n = #args
        if n == 0 then
            return nil
        elseif n == 1 then
            return args[1]
        elseif n == 2 then
            return args[1], args[2]
        elseif n == 3 then
            return args[1], args[2], args[3]
        elseif n == 4 then
            return args[1], args[2], args[3], args[4]
        elseif n == 5 then
            return args[1], args[2], args[3], args[4], args[5]
        elseif n == 6 then
            return args[1], args[2], args[3], args[4], args[5], args[6]
        elseif n == 7 then
            return args[1], args[2], args[3], args[4], args[5], args[6], args[7]
        elseif n == 8 then
            return args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]
        elseif n == 9 then
            return args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9]
        else
            ERROR(E2BIG, "resolve: method: arguments list too long")
        end
    end
end

function method.send(service, command, args)
    skynet.send(service, "lua", command, method.resolve(args))
end

function method.call(service, command, args)
    return skynet.call(service, "lua", command, method.resolve(args))
end

return method
