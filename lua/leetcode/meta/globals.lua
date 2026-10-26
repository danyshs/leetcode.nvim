---@meta
--- Optional third-party globals referenced defensively (behind pcall / plugin
--- presence checks). Declared here so static analysis knows they may exist
--- without emitting `undefined-global`. Type-only; emits no runtime code.

--- Provided by folke/snacks.nvim when installed; leetcode.nvim only touches it
--- inside pcall guards (see picker/init.lua).
---@type table
Snacks = Snacks
