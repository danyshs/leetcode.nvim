local config = require("leetcode.config")
local ok, image_api = pcall(require, "image")
local Group = require("leetcode-ui.group")
local Padding = require("leetcode-ui.lines.padding")
local Split = require("leetcode-ui.split")
local Parser = require("leetcode.parser")
local utils = require("leetcode.utils")
local t = require("leetcode.translator")

---@class lc.ui.Description : lc_ui.Split
---@field question lc.ui.Question
---@field urls     string[]         -- list of image URLs
---@field images   table<string,Image>
local Description = Split:extend("LeetDescription")
local group_id = vim.api.nvim_create_augroup("leetcode_description", { clear = true })

-- Debug notifications (commented out; uncomment to re-enable)
-- local function D(msg)
--     vim.notify("LeetCodeImgDebug: " .. msg, vim.log.levels.DEBUG)
-- end

function Description:init(parent)
    Description.super.init(self, {
        relative = "editor",
        position = config.user.description.position,
        size = config.user.description.width,
        enter = false,
        focusable = true,
    })
    self.question = parent
    self.show_stats = config.user.description.show_stats
    self.urls = {}
    self.images = {}
    Description._last = self
    -- D("init() done")
end

function Description:mount()
    Description.super.mount(self)
    -- D("mount() start")
    self:populate()

    local ui = require("leetcode-ui.utils")
    ui.buf_set_opts(self.bufnr, {
        buftype = "nofile",
        buflisted = false,
        filetype = config.name,
        modifiable = false,
    })
    ui.win_set_opts(self.winid, {
        wrap = not (ok and config.user.image_support),
        winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
    })
    ui.win_set_winfixbuf(self.winid)

    if not ok and config.user.image_support then
        vim.notify("image.nvim not found but image_support=true", vim.log.levels.ERROR)
    end

    self:draw()
    self:autocmds()
    -- D("mount() done")
    return self
end

function Description:autocmds()
    vim.api.nvim_create_autocmd("WinResized", {
        group = group_id,
        buffer = self.bufnr,
        callback = function()
            self:draw()
        end,
    })
end

function Description:populate()
    -- D("populate() start")
    local q = self.question.q
    local raw = utils.translate(q.content, q.translated_content)

    -- inject single leading-newline "(URL)" placeholder where each <img> appears
    raw = raw:gsub("<img[^>]-src=[\"'](https?://[^\"']+)[\"'][^>]->", function(url)
        return "\n(" .. url .. ")"
    end)
    -- D("raw after injection: " .. #raw .. " chars")

    -- collect URLs from those placeholders
    self.urls = {}
    for url in raw:gmatch("%((https?://%S+)%)") do
        table.insert(self.urls, url)
        -- D("collected URL → " .. url)
    end

    -- build header + stats
    local header = Group({}, { position = "center" })
    header:append(self.question.cache.link or "", "leetcode_alt")
    header:endgrp()

    header:insert(Padding(1))
    header:append(q.frontend_id .. ". ", "leetcode_normal")
    header:append(utils.translate(q.title, q.translated_title))
    if q.is_paid_only then
        header:append(" " .. t("Premium"), "leetcode_medium")
    end
    header:endgrp()

    local show_stats = self.show_stats
    if show_stats then
        header:append(t(q.difficulty), "leetcode_" .. q.difficulty:lower())
    else
        header:append("????", "leetcode_list")
    end
    if config.icons.hl.status[self.question.cache.status] then
        local s = config.icons.hl.status[self.question.cache.status]
        header:append(" "):append(s[1], s[2])
    end
    header:append((" %s "):format(config.icons.bar))

    local likes = show_stats and q.likes or "___"
    header:append(likes .. " ", "leetcode_alt")

    local dislikes = show_stats and q.dislikes or "___"
    if not config.is_cn then
        header:append((" %s "):format(dislikes), "leetcode_alt")
    end

    header:append((" %s "):format(config.icons.bar))

    local ac_rate = show_stats and q.stats.acRate or "__%"
    local total_sub = show_stats and q.stats.totalSubmission or "__"
    header:append(("%s %s %s"):format(ac_rate, t("of"), total_sub), "leetcode_alt")

    if not vim.tbl_isempty(q.hints) then
        header:append((" %s "):format(config.icons.bar))
        header:append("󰛨 " .. t("Hints"), "leetcode_hint")
    end
    header:endgrp()

    local contents = Parser:parse(raw)
    -- no extra Padding; placeholder sits exactly where needed
    self.renderer:replace({ header, contents })
    -- D("renderer:replace() done")
end

function Description:draw()
    Description.super.draw(self)
    self:draw_imgs()
end

function Description:draw_imgs()
    -- D("draw_imgs() start – img_support=" .. tostring(ok and config.user.image_support))
    if not ok or not config.user.image_support then
        -- D(" skipping images (support off)")
        return
    end

    -- clear previously rendered images
    for _, img in pairs(self.images) do
        img:clear(true)
    end
    self.images = {}

    local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
    for _, url in ipairs(self.urls) do
        for i, line in ipairs(lines) do
            if line:find(url, 1, true) then
                image_api.from_url(url, {
                    buffer = self.bufnr,
                    window = self.winid,
                    with_virtual_padding = true,
                }, function(fetched)
                    if not fetched then
                        vim.notify(
                            "LeetCodeImgDebug: fetch failed → " .. url,
                            vim.log.levels.ERROR
                        )
                        return
                    end
                    self.images[url] = fetched
                    fetched:render({ y = i })
                    -- D("rendered image at line " .. i)
                end)
                break
            end
        end
    end
end

function Description:toggle_stats()
    self.show_stats = not self.show_stats
    -- D("toggle_stats → show_stats=" .. tostring(self.show_stats))
    self:populate()
    self:draw()
end

-- clear images on exit
vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
        if Description._last then
            for _, img in pairs(Description._last.images or {}) do
                img:clear(true)
            end
        end
    end,
})

return Description
