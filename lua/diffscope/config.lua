local M = {}

M.defaults = {
  layout = {
    -- nil keeps the two code panes equal; set a number to force the base pane width.
    base_width = nil,
  },
  mappings = {
    close = "q",
    help = "?",
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
