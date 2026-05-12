local config = require("diffscope.config")

local M = {}

function M.setup(opts)
  config.setup(opts)
end

function M.config()
  return config.options
end

function M.open(args)
  require("diffscope.ui").open(args or {})
end

function M.close()
  require("diffscope.ui").close()
end

function M.open_file_picker()
  require("diffscope.ui").open_file_picker()
end

function M.reload()
  require("diffscope.ui").reload()
end

function M.toggle_reviewed()
  require("diffscope.ui").toggle_reviewed()
end

function M.filter_picker()
  require("diffscope.ui").filter_picker()
end

return M
