local h = require("tests.e2e.helpers")

local function open_repo_on_alpha()
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
  ["opens dedicated viewer/editor layout"] = function()
    local dir, cwd = open_repo_on_alpha()

    h.eq(#vim.api.nvim_tabpage_list_wins(0), 2, "Diffscope should own a two-window tab")

    local viewer_win, viewer_buf = h.find_win_by_bufname("Diffscope://diff/alpha.lua")
    h.truthy(viewer_win, "viewer window should exist")
    h.eq(vim.bo[viewer_buf].modifiable, false, "viewer should be read-only")
    h.eq(vim.bo[viewer_buf].readonly, true, "viewer should be readonly")

    local edit_buf = vim.api.nvim_get_current_buf()
    h.eq(vim.fs.normalize(vim.api.nvim_buf_get_name(edit_buf)), vim.fs.normalize(dir .. "/alpha.lua"), "current buffer should be real file")
    h.eq(vim.bo[edit_buf].modifiable, true, "editor should be modifiable")

    local viewer_winbar = vim.wo[viewer_win].winbar
    local edit_winbar = vim.wo[0].winbar
    h.contains(viewer_winbar, "Diffscope ·", "viewer winbar should identify Diffscope")
    h.contains(viewer_winbar, "alpha.lua", "viewer winbar should show file")
    h.contains(edit_winbar, "Edit ·", "editor winbar should identify edit pane")

    require("diffscope").close()
    vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    h.cleanup(dir)
  end,

  ["renders code-shaped diff without raw diff markers"] = function()
    local dir, cwd = open_repo_on_alpha()
    local _, viewer_buf = h.find_win_by_bufname("Diffscope://diff/alpha.lua")
    h.truthy(viewer_buf, "viewer buffer should exist")

    local text = h.join_lines(h.buf_lines(viewer_buf))
    h.contains(text, "return 'alpha'", "removed code should be rendered as code")
    h.contains(text, "return 'alpha changed'", "added code should be rendered as code")
    h.no_contains(text, "@@", "viewer should not show hunk headers")
    h.no_contains(text, "+  return 'alpha changed'", "viewer should not show plus markers")
    h.no_contains(text, "-  return 'alpha'", "viewer should not show minus markers")

    local ns = vim.api.nvim_get_namespaces().diffscope
    h.truthy(ns, "diffscope namespace should exist")
    local marks = vim.api.nvim_buf_get_extmarks(viewer_buf, ns, 0, -1, { details = true })
    local has_added = false
    local has_removed = false
    for _, mark in ipairs(marks) do
      local details = mark[4] or {}
      if details.line_hl_group == "DiffscopeAdded" then
        has_added = true
      elseif details.line_hl_group == "DiffscopeRemoved" then
        has_removed = true
      end
    end
    h.truthy(has_added, "viewer should highlight added lines")
    h.truthy(has_removed, "viewer should highlight removed lines")

    require("diffscope").close()
    vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    h.cleanup(dir)
  end,
}
