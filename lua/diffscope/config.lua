local M = {}

M.defaults = {
  layout = {
    -- nil keeps the diff viewer and editor equal; set a number to force viewer width.
    base_width = nil,
  },
  mappings = {
    close = "q",
    help = "?",
    next_hunk = "]c",
    prev_hunk = "[c",
    files = "f",
    next_file = "]f",
    prev_file = "[f",
    stage_file = "s",
    reset_file = "r",
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
