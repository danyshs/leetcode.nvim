-- Goal: pin LeetQ's title-matching behavior (the logic the pushpush deviation
-- duplicated and this refactor consolidated into cmd.match_question).
-- Methodology: call the pure matcher against a fixed problem list and assert the
-- (kind, payload) outcome for every branch: empty, exact, single-partial,
-- multi-partial, none; plus the argument-guard assertions.
local h = require("tests.harness")
local cmd = require("leetcode.command")

local problems = {
    { title = "Two Sum" },
    { title = "Add Two Numbers" },
    { title = "Longest Substring" },
    { title = "Two Pointers Intro" },
}

-- empty query -> "empty", returns the whole list (picker lists all)
local kind, payload = cmd.match_question(problems, "")
h.eq("empty: kind", "empty", kind)
h.eq("empty: returns full list", 4, #payload)

-- exact title (lowercased) -> "exact", that problem
kind, payload = cmd.match_question(problems, "two sum")
h.eq("exact: kind", "exact", kind)
h.eq("exact: right problem", "Two Sum", payload.title)

-- single partial -> "single", that problem
kind, payload = cmd.match_question(problems, "longest")
h.eq("single: kind", "single", kind)
h.eq("single: right problem", "Longest Substring", payload.title)

-- multiple partials -> "multi", the match list
kind, payload = cmd.match_question(problems, "two")
h.eq("multi: kind", "multi", kind)
h.eq("multi: match count", 3, #payload) -- Two Sum, Add Two Numbers, Two Pointers

-- no match -> "none", nil payload
kind, payload = cmd.match_question(problems, "dijkstra")
h.eq("none: kind", "none", kind)
h.eq("none: nil payload", nil, payload)

-- exact wins over partial even when partials also exist
kind, payload = cmd.match_question(problems, "two pointers intro")
h.eq("exact-over-partial: kind", "exact", kind)
h.eq("exact-over-partial: right problem", "Two Pointers Intro", payload.title)

-- entries without a .title are skipped, not crashed on
kind = cmd.match_question({ { nope = 1 }, { title = "Two Sum" } }, "two sum")
h.eq("skips titleless entries", "exact", kind)

-- argument guards fire on bad input
h.errors("match_question rejects non-table problems", cmd.match_question, "x", "q")
h.errors("match_question rejects non-string query", cmd.match_question, problems, 5)

h.done("command")
