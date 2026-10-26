local Text = require("nui.text")

---@class lc.ui.Indent : NuiText
---@field super NuiText
local Indent = Text:extend("LeetIndent")

---@param i? integer
---@param char? string
---@param hl? string|nui_text_extmark
function Indent:init(i, char, hl) --
    local text = ("\t"):rep(i or 0) .. (char or "")
    Indent.super.init(self, text, hl)
end

---@type lc.ui.Indent|fun(i?: integer, char?: string, hl?: string|nui_text_extmark): lc.ui.Indent
local LeetIndent = Indent

return LeetIndent
