local M = {}

local groups = {
  DiffscopeAdded = { bg = "#1f3d2b" },
  DiffscopeRemoved = { bg = "#4a2024" },
  DiffscopeChanged = { bg = "#3f351f" },
  DiffscopeChangedText = { bg = "#66512a", bold = true },
  DiffscopeFileModified = { link = "DiagnosticWarn" },
  DiffscopeFileAdded = { link = "DiagnosticOk" },
  DiffscopeFileDeleted = { link = "DiagnosticError" },
  DiffscopeFileRenamed = { link = "DiagnosticInfo" },
  DiffscopeFileUntracked = { link = "DiagnosticHint" },
  DiffscopeFileSelected = { link = "Visual" },
  DiffscopePanelTitle = { link = "Title" },
}

function M.setup()
  for name, spec in pairs(groups) do
    vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", { default = true }, spec))
  end
end

function M.status_group(status)
  status = status or ""
  local first = status:sub(1, 1)
  if first == "A" then
    return "DiffscopeFileAdded"
  elseif first == "D" then
    return "DiffscopeFileDeleted"
  elseif first == "R" then
    return "DiffscopeFileRenamed"
  elseif first == "?" then
    return "DiffscopeFileUntracked"
  end
  return "DiffscopeFileModified"
end

return M
