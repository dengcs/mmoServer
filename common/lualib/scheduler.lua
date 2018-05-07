local skynet = require "skynet"

local handler = {}

local scheduler = {}

local SESSION_SEQUENCE = SCHEDULER.INITIAL

function handler.schedule(func, interval, loop, args)
    SESSION_SEQUENCE = SESSION_SEQUENCE + 1
    local session = SESSION_SEQUENCE
    local f
    f = function ()
        local t = scheduler[session]
        if not t then
            return
        end

        if type(func) == "string" then
            -- service command
            local list = string.split(func)
            local s = nil
            local cmd = nil

            if #list == 1 then -- "function_name"
                cmd = list[1]
            elseif #list == 2 and list[1] ~= "" then -- "service_name.function_name"
                s = list[1]
                cmd = list[2]
            elseif #list == 3 and list[1] == "" then -- ".local_service_name.function_name"
                s = "." .. list[2]
                cmd = list[3]
            else
                ERROR(EINVAL, "schedule: %s: no such function or service", func)
            end

            if not s then
                _NOVA.COMMAND_DISPATCH.SEND("lua", cmd, args)
            else
                skynet.send(s, "lua", cmd, args)
            end
        elseif type(func) == "function" then
            -- function callback
            func(args)
        else
            ERROR(EINVAL, "schedule: %s: command not found", tostring(func))
        end

        if t.loop > 0 then
            t.loop = t.loop - 1
        end

        if t.loop == 0 then
            scheduler[session] = nil
            return
        end

        skynet.timeout(t.interval * TIMER.MILLISECOND_UNIT, t.handler)
    end

    interval = interval or 0
    loop = loop or 1

    local t = {
        handler = f,
        interval = interval,
        loop = loop,
    }
    scheduler[session] = t
    skynet.timeout(interval * TIMER.MILLISECOND_UNIT, f)
    return session
end

function handler.unschedule(session)
    local t = scheduler[session]
    if t then
        scheduler[session] = nil
    end
end

function handler.unschedule_all()
    for k, _ in pairs(scheduler) do
        handler.unschedule(k)
    end
end

return handler
