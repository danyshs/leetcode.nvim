-- Goal: pin Description.parse_image_urls, the pure logic every description image
-- is anchored to (an <img> becomes a "(URL)" placeholder line, and the image is
-- rendered at that line). The rendering itself needs a GUI terminal, but the
-- parse/collect step is pure and is where the historical image bugs lived.
-- Methodology: feed representative question HTML and assert both the rewritten
-- text (placeholder present, tag gone) and the collected URL list / order.
local h = require("tests.harness")
local Description = require("leetcode-ui.split.description")

-- single <img> -> one placeholder line, tag removed, one URL collected
local raw, urls = Description.parse_image_urls([[before<img src="https://x.com/a.png" />after]])
-- the placeholder must sit on its OWN line (leading \n): that is what makes the
-- image anchor to a dedicated row. Assert the newline-prefixed form explicitly.
h.is_true(
    "single: placeholder on its own line",
    raw:find("\n(https://x.com/a.png)", 1, true) ~= nil
)
h.is_true(
    "single: a newline precedes the placeholder",
    raw:match("\n%(https://x%.com/a%.png%)") ~= nil
)
h.is_true("single: original <img> tag removed", raw:find("<img", 1, true) == nil)
h.eq("single: one url collected", 1, #urls)
h.eq("single: url value", "https://x.com/a.png", urls[1])

-- multiple <img> -> URLs collected in document order
raw, urls = Description.parse_image_urls(
    [[<img src="https://x.com/1.png">mid<img src='https://x.com/2.png'>]]
)
h.eq("multi: two urls", 2, #urls)
h.eq("multi: order preserved 1", "https://x.com/1.png", urls[1])
h.eq("multi: order preserved 2", "https://x.com/2.png", urls[2])

-- no <img> -> text unchanged, no urls
raw, urls = Description.parse_image_urls("plain description, no images")
h.eq("none: text unchanged", "plain description, no images", raw)
h.eq("none: no urls", 0, #urls)

-- non-http src (data URI / relative) is NOT collected (pattern requires https?://)
local _, durls = Description.parse_image_urls([[<img src="data:image/png;base64,AAAA">]])
h.eq("data-uri: not collected", 0, #durls)

-- argument guard fires on non-string, with a DESCRIPTIVE message (not a raw
-- Lua error) -- the loud/descriptive-error discipline this refactor enforces.
local err = h.errors("parse_image_urls rejects non-string", Description.parse_image_urls, 42)
h.is_true(
    "reject message names the function+arg",
    tostring(err):find("parse_image_urls", 1, true) ~= nil
)

h.done("description")
