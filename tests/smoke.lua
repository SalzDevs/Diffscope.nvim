vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.cmd("runtime plugin/diffscope.lua")

require("diffscope").setup({})

assert(vim.fn.exists(":DiffScope") == 2, ":DiffScope command should exist")

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
vim.fn.system({ "git", "-C", tmp, "init" })
assert(vim.v.shell_error == 0, "git init should succeed")

vim.fn.writefile({ "hello", "diffscope" }, tmp .. "/sample.txt")
vim.fn.writefile({ "another", "change" }, tmp .. "/another.txt")
vim.cmd("cd " .. vim.fn.fnameescape(tmp))
vim.cmd("DiffScope")
require("diffscope").next_file()
require("diffscope").prev_file()
require("diffscope").reload()
require("diffscope").close()

vim.fn.delete(tmp, "rf")
