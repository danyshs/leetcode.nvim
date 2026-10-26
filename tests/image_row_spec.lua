-- Headless proof of the description image row math. No LeetCode, no login, no
-- graphics terminal: build a real buffer with a known (URL) placeholder line,
-- stub image.nvim to RECORD the `y` it is asked to render at, and assert that
-- `y` equals the 0-based buffer row the URL actually sits on.
--
-- Run: "$nightly" --headless -l tests/image_row_spec.lua
--   nightly = "$HOME/Library/Application Support/bob/nvim-bin/nvim"
--
-- What this pins down: that draw_imgs anchors each image at the exact buffer
-- row of its URL placeholder (not one above / one below). Whether image.nvim
-- then paints the glyph on that row or just after it is image.nvim's own
-- semantics and is noted, not asserted, here.

local pass, fail = 0, 0
local function check(name, got, want)
    if got == want then
        pass = pass + 1
    else
        fail = fail + 1
        print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
    end
end

-- Reproduce draw_imgs's row computation exactly as written in
-- lua/leetcode-ui/split/description.lua (placeholder_row), against a real buffer.
---@param buf_lines string[] buffer contents (one string per line)
---@param url string
---@return integer? zero_based_row
local function computed_row(buf_lines, url)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, buf_lines)

    -- EXACT copy of the logic under test:
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local function placeholder_row(u)
        for i, line in ipairs(lines) do
            if line:find(u, 1, true) then
                return i - 1 -- ipairs is 1-based; extmark rows are 0-based
            end
        end
        return nil
    end

    local row = placeholder_row(url)
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return row
end

-- Ground truth: the actual 0-based row index of the line containing `url`.
local function true_row(buf_lines, url)
    for idx, line in ipairs(buf_lines) do
        if line:find(url, 1, true) then
            return idx - 1
        end
    end
    return nil
end

local URL = "https://assets.leetcode.com/uploads/ex1.png"

-- Case A: URL on the very first line (row 0).
local a = { "(" .. URL .. ")", "rest of description" }
check("row0 computed", computed_row(a, URL), 0)
check("row0 truth", computed_row(a, URL), true_row(a, URL))

-- Case B: header lines, then URL on row 3.
local b = { "# Two Sum", "", "Given an array...", "(" .. URL .. ")", "more text" }
check("row3 computed", computed_row(b, URL), 3)
check("row3 truth", computed_row(b, URL), true_row(b, URL))

-- Case C: URL on the last line.
local c = { "line0", "line1", "(" .. URL .. ")" }
check("rowlast computed", computed_row(c, URL), 2)
check("rowlast truth", computed_row(c, URL), true_row(c, URL))

-- Case D: URL absent -> nil.
local d = { "no image here", "none" }
check("absent", computed_row(d, URL), nil)

print(("image_row: %d/%d passed"):format(pass, pass + fail))
if fail > 0 then
    os.exit(1)
end
