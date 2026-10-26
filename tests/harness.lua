-- Shared test harness for leetcode.nvim specs, run under `nvim --headless -l`.
-- Loads the plugin and its runtime deps against the REAL vim API (no mocks),
-- and provides minimal assert helpers. Keep this dependency-light on purpose:
-- a hard-forked plugin should test without luarocks/busted/nlua.
--
-- Run specs on the 0.13 nightly this config targets, NOT whatever `nvim` is on
-- PATH (often older). From the repo root, e.g.:
--   "$HOME/Library/Application Support/bob/nvim-bin/nvim" --headless -l tests/<spec>.lua
-- A spec that assumes a 0.13 API will silently pass on an older PATH nvim, so
-- always point at the nightly binary.

local M = {}

-- Put this plugin and its runtime deps on the runtimepath so `require` resolves
-- the same module graph Neovim would at runtime. Deps live in the user's lazy
-- dir; a spec fails loudly here if one is missing rather than mocking it away.
local function add_runtime_paths()
    local cwd = vim.fn.getcwd()
    vim.opt.runtimepath:prepend(cwd)
    package.path = cwd .. "/lua/?.lua;" .. cwd .. "/lua/?/init.lua;" .. package.path

    local lazy = vim.fn.expand("~/.local/share/nvim/lazy")
    local deps = { "plenary.nvim", "nui.nvim", "telescope.nvim" }
    for _, dep in ipairs(deps) do
        local dir = lazy .. "/" .. dep
        if vim.fn.isdirectory(dir) == 1 then
            vim.opt.runtimepath:prepend(dir)
        end
    end
end

add_runtime_paths()

-- counters so a runner file can report a suite-level pass/fail and os.exit
M.passed = 0
M.failed = 0

-- eq: assert two values are equal, with a labelled message on mismatch.
function M.eq(label, expected, actual)
    assert(type(label) == "string" and #label > 0, "eq: label must be a non-empty string")
    if expected == actual then
        M.passed = M.passed + 1
    else
        M.failed = M.failed + 1
        io.stderr:write(
            ("FAIL [%s]: expected %s, got %s\n"):format(
                label,
                vim.inspect(expected),
                vim.inspect(actual)
            )
        )
    end
end

-- is_true: assert a condition holds.
function M.is_true(label, cond)
    assert(type(label) == "string" and #label > 0, "is_true: label must be a non-empty string")
    M.eq(label, true, cond == true)
end

-- errors: assert that calling fn(...) raises, and return the error message.
function M.errors(label, fn, ...)
    assert(type(label) == "string" and #label > 0, "errors: label must be a non-empty string")
    assert(type(fn) == "function", "errors: fn must be a function")
    local ok, err = pcall(fn, ...)
    M.is_true(label .. " (should raise)", not ok)
    return err
end

-- done: print a summary line and exit non-zero if anything failed. A runner
-- calls this last so the shell gate sees the real status.
function M.done(suite)
    assert(type(suite) == "string" and #suite > 0, "done: suite must be a non-empty string")
    local total = M.passed + M.failed
    print(("%s: %d/%d passed"):format(suite, M.passed, total))
    if M.failed > 0 then
        os.exit(1)
    end
end

return M
