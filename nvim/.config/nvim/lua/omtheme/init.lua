local palette = require("omtheme.palette")
local groups  = require("omtheme.groups")

vim.o.termguicolors  = true
vim.o.background     = "dark"
vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") then vim.cmd("syntax reset") end
vim.g.colors_name = "omtheme"

groups.setup(palette)
