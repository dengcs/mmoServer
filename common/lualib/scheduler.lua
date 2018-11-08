local skynet = require "skynet"

local tb_unpack = table.unpack

local handler = {}

local scheduler = {}

local SESSION_SEQUENCE = 100000

local function timeout(interval, func)
    skynet.timeout(interval * TIMER.MILLISECOND_UNIT, func)
end

local function worker(t)
    scheduler[t.session] = t

    local function f()
        local tb = scheduler[t.session]
        if not tb then
            return
        end

        if IS_FUNCTION(tb.func) then
            pcall(tb.func, tb_unpack(tb.args or {}))
        else
            ERROR(EINVAL, "schedule: %s: command not found", tostring(func))
        end

        if tb.loop > 0 then
            tb.loop = tb.loop - 1
        end

        if tb.loop == 0 then
            scheduler[tb.session] = nil
        end

        timeout(tb.interval, f)
    end

    timeout(t.interval, f)
end

function handler.schedule(func, interval, loop, args)
    SESSION_SEQUENCE = SESSION_SEQUENCE + 1

    interval = interval or 0
    loop = loop or 1

    local t = {
        func = func,
        interval = interval,
        loop = loop,
        session = SESSION_SEQUENCE,
        args = args,
    }

    worker(t)

    return t.session
end

function handler.unschedule(session)
    local t = scheduler[session]
    if t then
        scheduler[session] = nil
    end
end

function handler.unschedule_all()
    for session, _ in pairs(scheduler) do
        scheduler[session] = nil
    end
end

return handler
