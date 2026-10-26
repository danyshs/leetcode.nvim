local utils = require("leetcode.api.utils")
local config = require("leetcode.config")
local log = require("leetcode.logger")
local queries = require("leetcode.api.queries")
local urls = require("leetcode.api.urls")

---@class lc.AuthApi
local Auth = {}

---@param cb? fun(user?: lc.UserStatus, err?: lc.err)
---@return lc.UserStatus? user  # nil when cb is given (result goes to cb) or auth fails
---@return lc.err? err
function Auth.user(cb)
    local query = queries.auth

    if cb then
        utils.query(query, {}, {
            callback = function(res, err)
                cb(Auth.handle(res, err))
            end,
            endpoint = urls.auth,
        })
    else
        return Auth.handle(utils.query(query, {}, {
            endpoint = urls.auth,
        }))
    end
end

---@private
---@return lc.UserStatus? user  # nil when auth fails; this is how "not signed in" propagates
---@return lc.err? err           # nil on success
function Auth.handle(res, err)
    if err then
        return res, err
    end

    local auth = res.data.userStatus
    err = {}

    if (not config.is_cn and auth.id == vim.NIL) or (config.is_cn and auth.slug == vim.NIL) then
        err.msg = "Cookie expired?"
    elseif not auth.is_signed_in then
        err.msg = "Sign-in failed"
    elseif not auth.is_verified then
        err.msg = "Please verify your email address in order to use your account"
    end

    if err.msg then
        require("leetcode.command").delete_cookie()
        return nil, err
    end

    config.auth = log.debug(auth)
    return auth, nil
end

return Auth
