local dired = require("dired")
local keymap = require("dired.keymap")

dired.refresh()
keymap.create_bindings()

vim.wo[0].winbar = "%=%{v:lua.vim.fn.getcwd()}%="
