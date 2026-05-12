local h = require("tests.e2e.helpers")

return {
  ["setup merges defaults"] = function()
    h.reset_diffscope_modules()
    local diffscope = require("diffscope")
    diffscope.setup({
      layout = { base_width = 44 },
      mappings = { files = "F" },
    })

    local cfg = diffscope.config()
    h.eq(cfg.layout.base_width, 44, "base_width should be overridden")
    h.eq(cfg.mappings.files, "F", "files mapping should be overridden")
    h.eq(cfg.mappings.reload, "R", "default reload mapping should be preserved")
  end,

  ["DiffScope command exists"] = function()
    h.eq(vim.fn.exists(":DiffScope"), 2, ":DiffScope should exist")
  end,
}
