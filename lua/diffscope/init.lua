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

return M
