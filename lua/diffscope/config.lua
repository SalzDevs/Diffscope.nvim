local M = {}

M.defaults = {
  layout = {
    -- nil keeps the diff viewer and editor equal; set a number to force viewer width.
    base_width = nil,
  },
  mappings = {
    close = "q",
    help = "?",
    files = "f",
    reload = "R",
    toggle_reviewed = "d",
    picker_filter = "/",
    stage_file = "s",
    reset_file = "r",
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
