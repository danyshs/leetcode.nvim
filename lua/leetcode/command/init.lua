local log = require("leetcode.logger")
local arguments = require("leetcode.command.arguments")
local config = require("leetcode.config")
local event = require("nui.utils.autocmd").event
local api = vim.api
local t = require("leetcode.translator")

---@class lc.Commands
local cmd = {}

---@param old_name string
---@param new_name string
function cmd.deprecate(old_name, new_name)
    log.warn(("`%s` is deprecated, use `%s` instead."):format(old_name, new_name))
end

function cmd.cache_update()
    require("leetcode.utils").auth_guard()
    require("leetcode.cache").update()
end

---@param options table<string, string[]>
function cmd.problems(options)
    require("leetcode.utils").auth_guard()

    local p = require("leetcode.cache.problemlist").get()
    local picker = require("leetcode.picker")
    picker.question(p, options)
end

---@param cb? function
function cmd.cookie_prompt(cb)
    local cookie = require("leetcode.cache.cookie")

    local popup_options = {
        relative = "editor",
        position = {
            row = "50%",
            col = "50%",
        },
        size = 40,
        border = {
            style = "rounded",
            text = {
                top = (" %s "):format(t("Enter cookie")),
                top_align = "left",
            },
        },
        win_options = {
            winhighlight = "Normal:Normal",
        },
    }

    local NuiInput = require("nui.input")
    local input = NuiInput(popup_options, {
        prompt = " 󰆘 ",
        on_submit = function(value)
            local err = cookie.set(value)

            if not err then
                log.info("Sign-in successful")
                cmd.start_user_session()
            else
                log.error("Sign-in failed: " .. err)
            end

            pcall(cb, not err and true or false)
        end,
    })

    input:mount()

    local keys = config.user.keys
    input:map("n", keys.toggle, function()
        input:unmount()
    end)
    input:on(event.BufLeave, function()
        input:unmount()
    end)
end

function cmd.sign_out()
    cmd.menu()

    log.warn("You're now signed out")
    cmd.delete_cookie()
    cmd.set_menu_page("signin")
end

---Sign out
function cmd.delete_cookie()
    config.auth = {}
    local cookie = require("leetcode.cache.cookie")
    cookie.delete()
end

cmd.q_close_all = function()
    local utils = require("leetcode.utils")
    local qs = utils.question_tabs()

    for _, tabp in ipairs(qs) do
        tabp.question:unmount()
    end
end

function cmd.exit()
    local leetcode = require("leetcode")
    leetcode.stop()
end

cmd.expire = vim.schedule_wrap(function()
    local tabp = api.nvim_get_current_tabpage()
    cmd.menu()

    cmd.cookie_prompt(function(success)
        if success then
            if api.nvim_tabpage_is_valid(tabp) then
                api.nvim_set_current_tabpage(tabp)
            end
            log.info("Successful re-login")
        else
            cmd.sign_out()
        end
    end)
end)

function cmd.qot()
    require("leetcode.utils").auth_guard()

    local problems = require("leetcode.api.problems")
    local Question = require("leetcode-ui.question")

    problems.question_of_today(function(qot, err)
        if err then
            return log.err(err)
        end
        local problemlist = require("leetcode.cache.problemlist")
        Question(problemlist.get_by_title_slug(qot.title_slug)):mount()
    end)
end

function cmd.random_question(opts)
    require("leetcode.utils").auth_guard()

    local problems = require("leetcode.cache.problemlist")
    local question = require("leetcode.api.question")

    if opts and opts.difficulty then
        opts.difficulty = opts.difficulty[1]:upper()
    end
    if opts and opts.status then
        opts.status = ({
            ac = "AC",
            notac = "TRIED",
            todo = "NOT_STARTED",
        })[opts.status[1]]
    end

    local q, err = question.random(opts)
    if err then
        return log.err(err)
    end

    local item = problems.get_by_title_slug(q.title_slug) or {}
    local Question = require("leetcode-ui.question")
    Question(item):mount()
end

function cmd.start_with_cmd()
    local leetcode = require("leetcode")
    if leetcode.start(false) then
        cmd.menu()
    end
end

function cmd.menu()
    local winid, bufnr = _Lc_state.menu.winid, _Lc_state.menu.bufnr
    local ok, tabp = pcall(api.nvim_win_get_tabpage, winid)
    local ui = require("leetcode-ui.utils")

    if ok then
        api.nvim_set_current_tabpage(tabp)
        ui.win_set_buf(winid, bufnr)
    else
        _Lc_state.menu:remount()
    end
end

function cmd.yank()
    local utils = require("leetcode.utils")
    local q = utils.curr_question()
    if not q then
        return
    end

    q:editor_yank_code()
end

---@param page lc-menu.page
function cmd.set_menu_page(page)
    _Lc_state.menu:set_page(page)
end

function cmd.start_user_session()
    cmd.set_menu_page("menu")
    config.stats.update()
end

function cmd.question_tabs()
    local picker = require("leetcode.picker")
    picker.tabs()
end

function cmd.change_lang()
    local utils = require("leetcode.utils")
    local q = utils.curr_question()
    if q then
        local picker = require("leetcode.picker")
        picker.language(q)
    end
end

function cmd.desc_toggle()
    local utils = require("leetcode.utils")
    local q = utils.curr_question()
    if q then
        q.description:toggle()
    end
end

function cmd.desc_toggle_stats()
    local utils = require("leetcode.utils")
    local q = utils.curr_question()
    if q then
        q.description:toggle_stats()
    end
end

function cmd.console()
    local utils = require("leetcode.utils")
    local q = utils.curr_question()
    if q then
        q.console:toggle()
    end
end

function cmd.info()
    local utils = require("leetcode.utils")
    local q = utils.curr_question()
    if q then
        q.info:toggle()
    end
end

function cmd.hints()
    cmd.info()
end

function cmd.q_run()
    local utils = require("leetcode.utils")
    utils.auth_guard()
    local q = utils.curr_question()
    if q then
        q.console:run()
    end
end

function cmd.q_submit()
    local utils = require("leetcode.utils")
    utils.auth_guard()
    local q = utils.curr_question()
    if q then
        q.console:run(true)
    end
end

function cmd.ui_skills()
    if config.is_cn then
        return
    end
    local skills = require("leetcode-ui.popup.skills")
    skills:show()
end

function cmd.ui_languages()
    local languages = require("leetcode-ui.popup.languages")
    languages:show()
end

function cmd.open()
    local utils = require("leetcode.utils")
    utils.auth_guard()
    local q = utils.curr_question()

    if q then
        if vim.ui.open then
            vim.ui.open(q.cache.link)
        else
            local command
            local os_name = vim.loop.os_uname().sysname

            if os_name == "Linux" then
                command = string.format("xdg-open '%s'", q.cache.link)
            elseif os_name == "Darwin" then
                command = string.format("open '%s'", q.cache.link)
            else
                command = string.format("start \"\" \"%s\"", q.cache.link)
            end

            vim.fn.jobstart(command, { detach = true })
        end
    end
end

function cmd.reset()
    local utils = require("leetcode.utils")
    utils.auth_guard()
    local q = utils.curr_question()
    if not q then
        return
    end

    q:editor_reset_code()
end

function cmd.last_submit()
    local utils = require("leetcode.utils")
    utils.auth_guard()
    local q = utils.curr_question()
    if not q then
        return
    end

    local question_api = require("leetcode.api.question")
    question_api.latest_submission(q.q.id, q.lang, function(res, err)
        if err then
            if err.status == 404 then
                log.error("You haven't submitted any code!")
            else
                log.err(err)
            end

            return
        end

        if type(res) == "table" and res.code then
            local lines = res.code
            q:editor_section_replace(lines, "code")
        else
            log.error("Something went wrong")
        end
    end)
end

function cmd.restore()
    local utils = require("leetcode.utils")
    local ui = require("leetcode-ui.utils")
    local q = utils.curr_question()
    if not q then
        return
    end

    if
        (q.winid and api.nvim_win_is_valid(q.winid))
        and (q.bufnr and api.nvim_buf_is_valid(q.bufnr))
    then
        ui.win_set_buf(q.winid, q.bufnr)
    end

    q.description:show()
    local winid, bufnr = q.description.winid, q.description.bufnr

    if (winid and api.nvim_win_is_valid(winid)) and (bufnr and api.nvim_buf_is_valid(bufnr)) then
        ui.win_set_buf(q.winid, q.bufnr)
    end
end

function cmd.inject()
    local utils = require("leetcode.utils")
    local q = utils.curr_question()
    if not q then
        return
    end

    if q.bufnr and api.nvim_buf_is_valid(q.bufnr) then
        local range = q:editor_section_range("code")

        if not range:is_valid_or_log() then
            return
        end

        local lines = table.concat(range.lines, "\n", range.start_i, range.end_i)

        q:editor_reset()
        q:editor_section_replace(lines, "code")
    end
end

function cmd.fold()
    local utils = require("leetcode.utils")
    local q = utils.curr_question()
    if not q then
        return
    end

    q:editor_fold_imports(true)
end

function cmd.get_active_session()
    local sessions = config.sessions.all
    return vim.tbl_filter(function(s)
        return s.is_active
    end, sessions)[1]
end

function cmd.get_session_by_name(name)
    local sessions = config.sessions.all

    name = name:lower()
    if name == config.sessions.default then
        name = ""
    end
    return vim.tbl_filter(function(s)
        return s.name:lower() == name
    end, sessions)[1]
end

function cmd.change_session(opts)
    require("leetcode.utils").auth_guard()

    local name = opts.name[1] or config.sessions.default

    local session = cmd.get_session_by_name(name)
    if not session then
        return log.error("Session not found")
    end

    local stats_api = require("leetcode.api.statistics")
    stats_api.change_session(session.id, function(_, err)
        if err then
            return log.err(err)
        end
        log.info(("Session changed to `%s`"):format(name))
        config.stats.update()
    end)
end

function cmd.create_session(opts)
    require("leetcode.utils").auth_guard()

    local name = opts.name[1]
    if not name then
        return log.error("Session name not provided")
    end

    local stats_api = require("leetcode.api.statistics")
    stats_api.create_session(name, function(_, err)
        if err then
            return log.err(err)
        end
        log.info(("session `%s` created"):format(name))
    end)
end

function cmd.update_sessions()
    require("leetcode.utils").auth_guard()
    config.stats.update_sessions()
end

function cmd.fix()
    require("leetcode.cache.cookie").delete()
    require("leetcode.cache.problemlist").delete()
    vim.cmd("qa!")
end

---@return string[], string[]
function cmd.parse(args)
    local parts = vim.split(vim.trim(args), "%s+")
    if args:sub(-1) == " " then
        parts[#parts + 1] = ""
    end

    local options = {}
    for _, part in ipairs(parts) do
        local opt = part:match("(.-)=.-")
        if opt then
            table.insert(options, opt)
        end
    end

    return parts, options
end

---@param tbl table
local function cmds_keys(tbl)
    return vim.tbl_filter(function(key)
        if type(key) ~= "string" then
            return false
        end
        if key:sub(1, 1) == "_" then
            return false
        end
        if tbl[key]._private then
            return false
        end

        return true
    end, vim.tbl_keys(tbl))
end

---@param _ string
---@param line string
---@return string[]
function cmd.complete(_, line)
    local args, options = cmd.parse(line:gsub("Leet%s", ""))
    return cmd.rec_complete(args, options, cmd.commands)
end

---@param args string[]
---@param options string[]
---@param cmds table<string, any>
---@return string[]
function cmd.rec_complete(args, options, cmds)
    if not cmds or vim.tbl_isempty(args) then
        return {}
    end

    if not cmds._args and cmds[args[1]] then
        return cmd.rec_complete(args, options, cmds[table.remove(args, 1)])
    end

    local txt, keys = args[#args], cmds_keys(cmds)
    if cmds._args then
        local option_keys = cmds_keys(cmds._args)
        option_keys = vim.tbl_filter(function(key)
            return not vim.tbl_contains(options, key)
        end, option_keys)
        option_keys = vim.tbl_map(function(key)
            return ("%s="):format(key)
        end, option_keys)
        keys = vim.tbl_extend("force", keys, option_keys)

        local s = vim.split(txt, "=")
        if s[2] and cmds._args[s[1]] then
            local vals = vim.split(s[2], ",")
            return vim.tbl_filter(function(key)
                return not vim.tbl_contains(vals, key) and key:find(vals[#vals], 1, true) == 1
            end, cmds._args[s[1]])
        end
    end

    return vim.tbl_filter(function(key)
        return not vim.tbl_contains(args, key) and key:find(txt, 1, true) == 1
    end, keys)
end

function cmd.exec(args)
    local cmds = cmd.commands
    local options = vim.empty_dict()

    for s in vim.gsplit(args.args:lower(), "%s+", { trimempty = true }) do
        local opt = vim.split(s, "=")

        if opt[2] then
            options[opt[1]] = vim.split(opt[2], ",", { trimempty = true })
        elseif cmds then
            cmds = cmds[s]
        else
            break
        end
    end

    if cmds and type(cmds[1]) == "function" then
        cmds[1](options) ---@diagnostic disable-line
    else
        log.error(("Invalid command: `%s %s`"):format(args.name, args.args))
    end
end

function cmd.setup()
    api.nvim_create_user_command("Leet", cmd.exec, {
        bar = true,
        bang = true,
        nargs = "?",
        desc = "Leet",
        complete = cmd.complete,
    })
end

vim.api.nvim_create_user_command("LeetQ", function(opts)
    local auth_retry_started = false

    local function is_signed_in()
        local ok, cookie_mod = pcall(require, "leetcode.cache.cookie")
        if not ok or not cookie_mod then
            return false
        end

        local get_ok, cookie_data = pcall(cookie_mod.get)
        return get_ok and cookie_data ~= nil and cookie_data ~= false
    end

    local function notify_msg(msg, level, replace)
        local notify_ok, notify = pcall(require, "notify")
        if not notify_ok then
            vim.notify(msg, level or vim.log.levels.INFO, { title = "LeetQ" })
            return nil
        end

        local opts = {
            title = "LeetQ",
            timeout = level == vim.log.levels.ERROR and 4000 or 1200,
        }

        if replace ~= nil then
            opts.replace = replace
        end

        local ok, notif = pcall(notify, msg, level or vim.log.levels.INFO, opts)
        if ok then
            return notif
        end

        opts.replace = nil
        local fallback_ok, fallback_notif = pcall(notify, msg, level or vim.log.levels.INFO, opts)
        if fallback_ok then
            return fallback_notif
        end

        vim.notify(msg, level or vim.log.levels.INFO, { title = "LeetQ" })
        return nil
    end

    local function mount_and_fix(problem_data)
        if not problem_data then
            log.error("LeetQ: No problem data to mount")
            return
        end

        local QuestionUI = require("leetcode-ui.question")
        local q_instance = QuestionUI(problem_data)
        q_instance:mount()

        vim.schedule(function()
            if q_instance.winid and vim.api.nvim_win_is_valid(q_instance.winid) then
                vim.api.nvim_set_current_win(q_instance.winid)
            end
            vim.cmd("stopinsert")
        end)
    end

    local function ensure_started()
        local ok, leetcode = pcall(require, "leetcode")
        if ok and leetcode and leetcode.start then
            pcall(leetcode.start, false)
        end
    end

    local function run_after_auth_wait()
        local notif_ref = notify_msg("Checking LeetCode session...")
        local waited_ms = 0
        local interval_ms = 200
        local max_wait_ms = 7000

        local timer = vim.loop.new_timer()
        if not timer then
            vim.cmd("Leet")
            return
        end

        timer:start(
            0,
            interval_ms,
            vim.schedule_wrap(function()
                waited_ms = waited_ms + interval_ms

                local utils_ok, utils = pcall(require, "leetcode.utils")
                local auth_ready = false

                if utils_ok and utils and utils.auth_guard then
                    auth_ready = pcall(utils.auth_guard)
                end

                if auth_ready then
                    if not timer:is_closing() then
                        timer:stop()
                        timer:close()
                    end

                    notify_msg("Signed in. Loading question...", vim.log.levels.INFO, notif_ref)
                    vim.defer_fn(function()
                        local ok_run, err = pcall(function()
                            local input_str = table.concat(opts.fargs, " "):lower()
                            local problems_module = require("leetcode.cache.problemlist")
                            local Picker = require("leetcode.picker")

                            local ok, result = pcall(problems_module.get)
                            if not ok or type(result) ~= "table" then
                                log.error("LeetQ: Failed to get problem list")
                                vim.notify(
                                    "LeetQ: Could not retrieve problem list.",
                                    vim.log.levels.ERROR,
                                    {
                                        title = "LeetQ",
                                    }
                                )
                                return
                            end

                            local all_problems_list = result

                            if input_str == "" then
                                Picker.question(all_problems_list)
                                return
                            end

                            local matches = {}
                            local exact_match_problem = nil

                            for _, p_data in ipairs(all_problems_list) do
                                if p_data and p_data.title then
                                    local title_lower = p_data.title:lower()

                                    if title_lower == input_str then
                                        exact_match_problem = p_data
                                        break
                                    elseif title_lower:find(input_str, 1, true) then
                                        table.insert(matches, p_data)
                                    end
                                end
                            end

                            if exact_match_problem then
                                mount_and_fix(exact_match_problem)
                                return
                            end

                            if #matches == 0 then
                                vim.notify(
                                    "LeetQ: No matching questions found for '" .. input_str .. "'.",
                                    vim.log.levels.WARN,
                                    { title = "LeetQ" }
                                )
                                return
                            end

                            if #matches == 1 then
                                mount_and_fix(matches[1])
                                return
                            end

                            Picker.question(matches)
                        end)

                        if not ok_run then
                            log.error("LeetQ: " .. tostring(err))
                        end
                    end, 100)

                    return
                end

                if waited_ms == interval_ms then
                    vim.cmd("Leet")
                    notify_msg("Starting LeetCode sign-in...", vim.log.levels.INFO, notif_ref)
                end

                if waited_ms >= max_wait_ms then
                    if not timer:is_closing() then
                        timer:stop()
                        timer:close()
                    end

                    notify_msg(
                        "LeetCode sign-in timed out. Run ':Leet' or ':Leet cookie update' and try again.",
                        vim.log.levels.ERROR,
                        notif_ref
                    )
                end
            end)
        )
    end

    local function run_question_logic()
        local utils_ok, utils = pcall(require, "leetcode.utils")
        local auth_ok = utils_ok and utils and utils.auth_guard and pcall(utils.auth_guard)

        if not auth_ok then
            if not auth_retry_started then
                auth_retry_started = true
                run_after_auth_wait()
            end
            return
        end

        local input_str = table.concat(opts.fargs, " "):lower()
        local problems_module = require("leetcode.cache.problemlist")
        local Picker = require("leetcode.picker")

        local ok, result = pcall(problems_module.get)
        if not ok or type(result) ~= "table" then
            log.error("LeetQ: Failed to get problem list")
            vim.notify("LeetQ: Could not retrieve problem list.", vim.log.levels.ERROR, {
                title = "LeetQ",
            })
            return
        end

        local all_problems_list = result

        if input_str == "" then
            Picker.question(all_problems_list)
            return
        end

        local matches = {}
        local exact_match_problem = nil

        for _, p_data in ipairs(all_problems_list) do
            if p_data and p_data.title then
                local title_lower = p_data.title:lower()

                if title_lower == input_str then
                    exact_match_problem = p_data
                    break
                elseif title_lower:find(input_str, 1, true) then
                    table.insert(matches, p_data)
                end
            end
        end

        if exact_match_problem then
            mount_and_fix(exact_match_problem)
            return
        end

        if #matches == 0 then
            vim.notify(
                "LeetQ: No matching questions found for '" .. input_str .. "'.",
                vim.log.levels.WARN,
                { title = "LeetQ" }
            )
            return
        end

        if #matches == 1 then
            mount_and_fix(matches[1])
            return
        end

        Picker.question(matches)
    end

    ensure_started()

    if is_signed_in() then
        run_question_logic()
    else
        run_after_auth_wait()
    end
end, {
    nargs = "*",
    desc = "LeetQ: Fuzzy open LeetCode question by title or list all if no args.",
    complete = function(arglead)
        local cookie_ok, cookie_mod = pcall(require, "leetcode.cache.cookie")
        if not cookie_ok or not cookie_mod then
            return {}
        end

        local signed_in_ok, cookie_data = pcall(cookie_mod.get)
        if not signed_in_ok or not cookie_data then
            return { "-- Sign in to LeetCode first --" }
        end

        local problems_ok, problems_module = pcall(require, "leetcode.cache.problemlist")
        if not problems_ok or not problems_module then
            return { "-- Error loading problems module --" }
        end

        local ok, all_problems_list = pcall(problems_module.get)
        if not ok or type(all_problems_list) ~= "table" then
            return { "-- Error retrieving problem list --" }
        end

        local titles = {}
        for _, p_data in ipairs(all_problems_list) do
            if p_data and p_data.title then
                table.insert(titles, p_data.title)
            end
        end

        if arglead == nil or arglead == "" then
            return titles
        end

        local filtered_titles = {}
        local lead_lower = arglead:lower()

        for _, title_str in ipairs(titles) do
            if title_str:lower():find(lead_lower, 1, true) then
                table.insert(filtered_titles, title_str)
            end
        end

        return filtered_titles
    end,
})

cmd.commands = {
    cmd.menu,

    menu = { cmd.menu },
    exit = { cmd.exit },
    console = { cmd.console },
    info = { cmd.info },
    hints = { cmd.hints },
    tabs = { cmd.question_tabs },
    lang = { cmd.change_lang },
    run = { cmd.q_run },
    test = { cmd.q_run },
    submit = { cmd.q_submit },
    daily = { cmd.qot },
    yank = { cmd.yank },
    open = { cmd.open },
    reset = { cmd.reset },
    last_submit = { cmd.last_submit },
    restore = { cmd.restore },
    inject = { cmd.inject },
    fold = { cmd.fold },
    list = {
        cmd.problems,
        _args = arguments.list,
    },
    random = {
        cmd.random_question,
        _args = arguments.random,
    },
    desc = {
        cmd.desc_toggle,

        stats = { cmd.desc_toggle_stats },
        toggle = { cmd.desc_toggle },
    },
    cookie = {
        update = { cmd.cookie_prompt },
        delete = { cmd.sign_out },
    },
    cache = {
        update = { cmd.cache_update },
    },
    fix = {
        cmd.fix,
        _private = true,
    },
}

return cmd
