local h = require("tests.e2e.helpers")

local function open_repo()
  h.reset_diffscope_modules()
  require("diffscope").setup({})
  local dir = h.temp_repo()
  local cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(dir))
  vim.cmd("edit " .. vim.fn.fnameescape(dir .. "/alpha.lua"))
  vim.cmd("DiffScope")
  return dir, cwd
end

return {
  ["stage action stages current file"] = function()
    local dir, cwd = open_repo()

    require("diffscope.ui").stage_file()
    local staged = table.concat(h.run_git(dir, { "diff", "--cached", "--name-only" }), "\n")
    h.contains(staged, "alpha.lua", "stage action should stage current file")

    require("diffscope").close()
    vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    h.cleanup(dir)
  end,

  ["reset action requires two presses and keeps layout valid"] = function()
    local dir, cwd = open_repo()

    require("diffscope.ui").reset_file()
    local unstaged_after_first = table.concat(h.run_git(dir, { "diff", "--name-only", "--", "alpha.lua" }), "\n")
    h.contains(unstaged_after_first, "alpha.lua", "first reset press should only arm reset")

    require("diffscope.ui").reset_file()
    local unstaged_after_second = table.concat(h.run_git(dir, { "diff", "--name-only", "--", "alpha.lua" }), "\n")
    h.eq(unstaged_after_second, "", "second reset press should reset current file")
    h.eq(#vim.api.nvim_tabpage_list_wins(0), 2, "Diffscope layout should remain valid if other files are changed")

    require("diffscope").close()
    vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    h.cleanup(dir)
  end,
}
