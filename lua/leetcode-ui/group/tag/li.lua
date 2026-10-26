local Tag = require("leetcode-ui.group.tag")
local Lines = require("leetcode-ui.lines")
local Text = require("nui.text")
local List = require("leetcode-ui.group.tag.list")

local u = require("leetcode-ui.utils")
local log = require("leetcode.logger")

---@class lc.ui.Tag.li : lc.ui.Tag
---@field super lc.ui.Tag
---@field indent string
local Li = Tag:extend("LeetTagUl")

function Li:contents()
    local items = Li.super.contents(self)

    table.insert(items, 1, Text(self.pre, "leetcode_list"))

    return items
end

function Li:init(text, opts, node, tags)
    Li.super.init(self, text, opts, node, tags)

    self.pre = ""

    local r = #self.tags
    while r >= 1 and not u.is_instance(self.tags[r], List) do
        r = r - 1
    end

    local parent = self.tags[r] --[[@as lc.ui.Tag.List?]]

    if parent then
        if parent.order then
            self.pre = parent.order .. ". "
            parent.order = parent.order + 1
        else
            self.pre = "* "
        end
    end
end

---@type lc.ui.Tag.li|fun(): lc.ui.Tag.li
local LeetTagUl = Li

return LeetTagUl
