local M = {}

M.defaults = {
  layout = {
    file_panel_width = 32,
  },
  view = {
    default = "unified",
  },
  mappings = {
    close = "q",
    help = "?",
    preview = "p",
    open_split = "<CR>",
    next_hunk = "]c",
    prev_hunk = "[c",
    stage_file = "s",
    reset_file = "r",
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
