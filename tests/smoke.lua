vim.opt.runtimepath:append(vim.fn.getcwd())
vim.cmd("runtime plugin/diffscope.lua")

require("diffscope").setup({})

assert(vim.fn.exists(":DiffScope") == 2, ":DiffScope command should exist")

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
vim.fn.system({ "git", "-C", tmp, "init" })
assert(vim.v.shell_error == 0, "git init should succeed")

vim.fn.writefile({ "hello", "diffscope" }, tmp .. "/sample.txt")
vim.cmd("cd " .. vim.fn.fnameescape(tmp))
vim.cmd("DiffScope")
require("diffscope").close()

vim.fn.delete(tmp, "rf")
