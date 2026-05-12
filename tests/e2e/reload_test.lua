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
  ["external update marks both panes stale"] = function()
    local dir, cwd = open_repo()

    h.write(dir .. "/alpha.lua", {
      "local M = {}",
      "",
      "function M.alpha()",
      "  return 'agent changed alpha'",
      "end",
      "",
      "return M",
    })

    vim.wait(650)
    vim.api.nvim_exec_autocmds("CursorHold", {})

    local viewer_win = h.find_win_by_bufname("Diffscope://diff/alpha.lua")
    h.truthy(viewer_win, "viewer should exist")
    h.contains(vim.wo[viewer_win].winbar, "stale (R)", "viewer winbar should show stale")
    h.contains(vim.wo[0].winbar, "stale (R)", "editor winbar should show stale")

    require("diffscope").close()
    vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    h.cleanup(dir)
  end,

  ["reload clears stale and updates file list"] = function()
    local dir, cwd = open_repo()

    h.write(dir .. "/gamma.lua", { "return 'gamma'" })
    vim.wait(650)
    vim.api.nvim_exec_autocmds("CursorHold", {})
    require("diffscope").reload()
    require("diffscope").open_file_picker()

    local _, picker_buf = h.find_win_by_bufname("Diffscope://files")
    h.truthy(picker_buf, "picker should exist")
    local text = h.join_lines(h.buf_lines(picker_buf))
    h.contains(text, "gamma.lua", "reload should include externally-created changed file")

    local viewer_win = h.find_win_by_bufname("Diffscope://diff/alpha.lua")
    h.truthy(viewer_win, "viewer should exist")
    h.no_contains(vim.wo[viewer_win].winbar, "stale (R)", "reload should clear stale state")

    require("diffscope").close()
    vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    h.cleanup(dir)
  end,
}
