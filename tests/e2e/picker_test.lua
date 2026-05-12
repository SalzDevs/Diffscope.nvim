local h = require("tests.e2e.helpers")

local function open_with_picker()
  h.reset_diffscope_modules()
  require("diffscope").setup({})
  local dir = h.temp_repo()
  local cwd = vim.fn.getcwd()
  vim.cmd("cd " .. vim.fn.fnameescape(dir))
  vim.cmd("edit " .. vim.fn.fnameescape(dir .. "/alpha.lua"))
  vim.cmd("DiffScope")
  require("diffscope").open_file_picker()
  local picker_win, picker_buf = h.find_win_by_bufname("Diffscope://files")
  h.truthy(picker_win, "picker window should exist")
  return dir, cwd, picker_win, picker_buf
end

return {
  ["picker shows changed files with stats"] = function()
    local dir, cwd, _, picker_buf = open_with_picker()

    local text = h.join_lines(h.buf_lines(picker_buf))
    h.contains(text, "changed files", "picker should show header")
    h.contains(text, "alpha.lua", "picker should list alpha.lua")
    h.contains(text, "beta.lua", "picker should list beta.lua")
    h.contains(text, "+", "picker should show additions")
    h.contains(text, "-", "picker should show deletions")

    local ns = vim.api.nvim_get_namespaces().diffscope
    local marks = vim.api.nvim_buf_get_extmarks(picker_buf, ns, 0, -1, { details = true })
    local has_added = false
    local has_removed = false
    for _, mark in ipairs(marks) do
      local details = mark[4] or {}
      if details.hl_group == "DiffscopePickerAdded" then
        has_added = true
      elseif details.hl_group == "DiffscopePickerRemoved" then
        has_removed = true
      end
    end
    h.truthy(has_added, "addition stats should be highlighted")
    h.truthy(has_removed, "deletion stats should be highlighted")

    require("diffscope").close()
    vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    h.cleanup(dir)
  end,

  ["picker reviewed marker updates"] = function()
    local dir, cwd, _, picker_buf = open_with_picker()

    require("diffscope").toggle_reviewed()
    local text = h.join_lines(h.buf_lines(picker_buf))
    h.contains(text, "✓", "picker should show reviewed marker")

    require("diffscope").close()
    vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    h.cleanup(dir)
  end,

  ["opening a picker file switches editor and closes picker"] = function()
    local dir, cwd, _, _ = open_with_picker()

    require("diffscope.ui").open_file(2)
    local picker_win = h.find_win_by_bufname("Diffscope://files")
    h.eq(picker_win, nil, "picker should close after file selection")
    h.contains(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()), "beta.lua", "editor should switch to selected file")

    require("diffscope").close()
    vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    h.cleanup(dir)
  end,
}
