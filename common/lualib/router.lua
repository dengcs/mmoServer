local router = {}

local gets = {}
local posts = {}

-- 设置get路由
function router.get(path, handler)
    if string.sub(path,-1,-1) ~= "/" then
        path = path .. "/"
    end
    if path:match("/:") then
        local pattern = path:gsub("/(:[a-z]+)", "/([^/]+)")
        local names = {path:match("/:([a-z]+)")}
        path = function(path)
            local matches = {path:match(pattern)}
            if #matches == 0 or not matches[1] then return end
            local params = {}
            for i, name in ipairs(names) do
                params[name] = matches[i]
            end
            return params
        end
    end
    gets[#gets + 1] = {path, handler}
end

-- 设置post路由
function router.post(path, handler)
    if string.sub(path,-1,-1) ~= "/" then
        path = path .. "/"
    end
    if path:match("/:") then
        local pattern = path:gsub("/(:[a-z]+)", "/([^/]+)")
        local names = {path:match("/:([a-z]+)")}
        path = function(path)
            local matches = {path:match(pattern)}
            if #matches == 0 or not matches[1] then return end
            local params = {}
            for i, name in ipairs(names) do
                params[name] = matches[i]
            end
            return params
        end
    end
    posts[#posts + 1] = {path, handler}
end

-- 设置all路由
function router.all(path, handler)
    router.get(path, handler)
    router.post(path, handler)
end

-- get 请求处理
local function get_handler(req, res)
    for i, pair in ipairs(gets) do
        local path, handler = table.unpack(pair)
        if type(path) == "function" then
            local matches = path(req.url.path)
            if matches then
                req.params = matches
                handler(req, res)
                return
            end
        elseif req.url.path == path then
            req.params = req.params or {}
            handler(req, res)
            return
        end
    end

    if router.default_handler then
        return router.default_handler(req, res)
    end

    res.status(404)
end

-- post 请求处理
local function post_handler(req, res)
    for i, pair in ipairs(posts) do
        local path, handler = table.unpack(pair)
        if type(path) == "function" then
            local matches = path(req.url.path)
            if matches then
                req.params = matches
                handler(req, res)
                return
            end
        elseif req.url.path == path then
            req.params = req.params or {}
            handler(req, res)
            return
        end
    end

    if router.default_handler then
        return router.default_handler(req, res)
    end

    res.status(404)
end

-- 请求处理
function router.request_handler(req, res)
    if router.before_handler then
        local suc, err = pcall(router.before_handler, req, res)
        if not suc then
            if router.error_handler then
                return router.error_handler(err, req, res)
            else
                res.status(404)
                return
            end
        end
    end
    if req.method == "get" then
        local suc, err = pcall(get_handler, req, res)
        if not suc then
            if router.error_handler then
                return router.error_handler(err, req, res)
            else
                res.status(404)
                return
            end
        end
    elseif req.method == "post" then
        local suc, err = pcall(post_handler, req, res)
        if not suc then
            if router.error_handler then
                return router.error_handler(err, req, res)
            else
                res.status(404)
                return
            end
        end
    else
        res.status(404)
    end
end

return router 
