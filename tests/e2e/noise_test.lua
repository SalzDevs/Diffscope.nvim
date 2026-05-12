local h = require("tests.e2e.helpers")

return {
  ["routine operations do not emit old noisy status messages"] = function()
    h.reset_diffscope_modules()
    require("diffscope").setup({})
    local dir = h.temp_repo()
    local cwd = vim.fn.getcwd()
    vim.cmd("cd " .. vim.fn.fnameescape(dir))
    vim.cmd("edit " .. vim.fn.fnameescape(dir .. "/alpha.lua"))

    vim.cmd("messages clear")
    vim.cmd("DiffScope")
    require("diffscope.ui").open_file(2)
    require("diffscope").reload()

    local messages = vim.api.nvim_exec2("messages", { output = true }).output
    h.no_contains(messages, "Diff viewer opened", "open should be quiet")
    h.no_contains(messages, "Diffscope file", "file switching should be quiet")
    h.no_contains(messages, "Reloaded Diffscope changes", "reload should be quiet")

    require("diffscope").close()
    vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    h.cleanup(dir)
  end,
}
