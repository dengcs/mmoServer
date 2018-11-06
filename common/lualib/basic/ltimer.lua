--[[

os.date(format)

格式信息参数定义如下：
%a  abbreviated weekday name (e.g., Wed)
%A  full weekday name (e.g., Wednesday)
%b  abbreviated month name (e.g., Sep)
%B  full month name (e.g., September)
%c  date and time (e.g., 09/16/98 23:48:10)
%d  day of the month (16) [01-31]
%H  hour, using a 24-hour clock (23) [00-23]
%I  hour, using a 12-hour clock (11) [01-12]
%M  minute (48) [00-59]
%m  month (09) [01-12]
%p  either "am" or "pm" (pm)
%S  second (10) [00-61]
%w  weekday (3) [0-6 = Sunday-Saturday]
%x  date (e.g., 09/16/98)
%X  time (e.g., 23:48:10)
%Y  full year (1998)
%y  two-digit year (98) [00-99]
%%  the character '%'

]]

TIMER = {}

-- 在当前引擎中毫秒转换为秒时的进制单位
TIMER.MILLISECOND_UNIT = 100

function TIMER.NOW()
    return os.time()
end

function TIMER.YEAR()
    return os.date("%Y")
end

function TIMER.MONTH()
    return os.date("%m")
end

function TIMER.DAY()
    return os.date("%d")
end

function TIMER.HOUR()
    return os.date("%H")
end

function TIMER.MINUTE()
    return os.date("%M")
end

function TIMER.SECOND()
    return os.date("%S")
end
