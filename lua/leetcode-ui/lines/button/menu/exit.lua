local MenuButton = require("leetcode-ui.lines.button.menu")
local leetcode = require("leetcode")

---@class lc.ui.Button.Menu.Exit : lc.ui.Button.Menu
---@field super lc.ui.Button.Menu
local MenuExitButton = MenuButton:extend("LeetMenuExitButton")

function MenuExitButton:init()
    MenuExitButton.super.init(self, "Exit", {
        icon = "󰩈",
        sc = "qa",
        on_press = leetcode.stop,
    })
end

---@type lc.ui.Button.Menu.Exit|fun(): lc.ui.Button.Menu.Exit
local LeetMenuExitButton = MenuExitButton

return LeetMenuExitButton
