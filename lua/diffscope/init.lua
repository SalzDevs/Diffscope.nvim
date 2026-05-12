local config = require("diffscope.config")

local M = {}

function M.setup(opts)
  config.setup(opts)
end

function M.open(args)
  require("diffscope.ui").open(args or {})
end

function M.close()
  require("diffscope.ui").close()
end

function M.next_file()
  require("diffscope.ui").next_file()
end

function M.prev_file()
  require("diffscope.ui").prev_file()
end

function M.open_file_picker()
  require("diffscope.ui").open_file_picker()
end

function M.reload()
  require("diffscope.ui").reload()
end

return M
