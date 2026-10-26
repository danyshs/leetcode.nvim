local config = require("leetcode.config")
local ok, image_api = pcall(require, "image")
local Group = require("leetcode-ui.group")
local Padding = require("leetcode-ui.lines.padding")
local Split = require("leetcode-ui.split")
local Parser = require("leetcode.parser")
local utils = require("leetcode.utils")
local log = require("leetcode.logger")
local t = require("leetcode.translator")

---@class lc.ui.Description : lc_ui.Split
---@field question lc.ui.Question
---@field urls     string[]         -- list of image URLs
---@field images   table<string,Image>
local Description = Split:extend("LeetDescription")
local group_id = vim.api.nvim_create_augroup("leetcode_description", { clear = true })

---Rewrite each `<img src="URL">` in `raw` to a `\n(URL)` placeholder line and
---collect the URLs in document order. Pure and buffer-free so the image-anchor
---logic (which every image's placement depends on) is unit-testable without a
---GUI terminal or a live question.
---@param raw string the translated question HTML/markdown
---@return string rewritten, string[] urls
function Description.parse_image_urls(raw)
    assert(type(raw) == "string", "parse_image_urls: raw must be a string")

    local rewritten = raw:gsub("<img[^>]-src=[\"'](https?://[^\"']+)[\"'][^>]->", function(url)
        return "\n(" .. url .. ")"
    end)

    local urls = {}
    for url in rewritten:gmatch("%((https?://%S+)%)") do
        table.insert(urls, url)
    end

    return rewritten, urls
end

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
end

function Description:mount()
    Description.super.mount(self)
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
        log.error(
            "leetcode: `image_support` is enabled but image.nvim failed to load: "
                .. tostring(image_api)
        )
    end

    self:draw()
    self:autocmds()
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
    local q = self.question.q
    local raw = utils.translate(q.content, q.translated_content)

    -- rewrite <img> tags to (URL) placeholder lines and collect the URLs those
    -- placeholders anchor the images to (see Description.parse_image_urls)
    raw, self.urls = Description.parse_image_urls(raw)

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
end

function Description:draw()
    Description.super.draw(self)
    self:draw_imgs()
end

function Description:draw_imgs()
    if not ok or not config.user.image_support then
        return
    end

    -- A redraw (resize/stats toggle) re-runs populate(), so the buffer and its
    -- placeholder lines are rebuilt. image.nvim binds each image to an extmark
    -- it follows (with_virtual_padding forces inline), but the extmarks are
    -- cleared with the old buffer content, so we clear and re-place. We re-use
    -- the already-fetched image object where we have it, and only hit the
    -- network via from_url for URLs not yet fetched.
    local bufnr, winid = self.bufnr, self.winid
    if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
        return
    end
    if not (winid and vim.api.nvim_win_is_valid(winid)) then
        return
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    ---Row (0-based extmark row) of the placeholder line holding `url`, or nil.
    local function placeholder_row(url)
        for i, line in ipairs(lines) do
            if line:find(url, 1, true) then
                return i - 1 -- ipairs is 1-based; extmark rows are 0-based
            end
        end
        return nil
    end

    for _, url in ipairs(self.urls) do
        local row = placeholder_row(url)
        if row then
            local cached = self.images[url]
            if cached then
                cached:render({ y = row })
            else
                image_api.from_url(url, {
                    buffer = bufnr,
                    window = winid,
                    with_virtual_padding = true,
                }, function(fetched)
                    if not fetched then
                        log.error(("leetcode: failed to fetch description image: %s"):format(url))
                        return
                    end
                    -- the split may have closed during the async fetch
                    if not vim.api.nvim_buf_is_valid(bufnr) then
                        fetched:clear(true)
                        return
                    end
                    self.images[url] = fetched
                    fetched:render({ y = row })
                end)
            end
        end
    end
end

function Description:toggle_stats()
    self.show_stats = not self.show_stats
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
