local h = require("tests.e2e.helpers")

return {
  ["git source lists working tree changes"] = function()
    h.reset_diffscope_modules()
    local dir = h.temp_repo()
    local cwd = vim.fn.getcwd()
    vim.cmd("cd " .. vim.fn.fnameescape(dir))

    local src = require("diffscope.source").from_args({})
    h.eq(src.kind, "git", "source kind")
    h.eq(src.mode, "working", "source mode")
    h.truthy(#src.files >= 2, "expected changed files")

    local paths = {}
    for _, file in ipairs(src.files) do
      paths[file.path] = true
    end
    h.truthy(paths["alpha.lua"], "alpha.lua should be changed")
    h.truthy(paths["beta.lua"], "beta.lua should be changed")

    vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    h.cleanup(dir)
  end,

  ["staged source lists staged changes"] = function()
    h.reset_diffscope_modules()
    local dir = h.temp_repo()
    local cwd = vim.fn.getcwd()
    h.write(dir .. "/staged.lua", { "return 'staged'" })
    h.run_git(dir, { "add", "staged.lua" })
    vim.cmd("cd " .. vim.fn.fnameescape(dir))

    local src = require("diffscope.source").from_args({ "staged" })
    h.eq(src.mode, "staged", "source mode")

    local found = false
    for _, file in ipairs(src.files) do
      if file.path == "staged.lua" then
        found = true
      end
    end
    h.truthy(found, "staged.lua should be staged")

    vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    h.cleanup(dir)
  end,

  ["file compare source opens two explicit files"] = function()
    h.reset_diffscope_modules()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    h.write(dir .. "/left.lua", { "return 'left'" })
    h.write(dir .. "/right.lua", { "return 'right'" })

    local src = require("diffscope.source").from_args({ dir .. "/left.lua", dir .. "/right.lua" })
    h.eq(src.kind, "files", "source kind")
    h.eq(#src.files, 1, "file compare should have one file entry")
    h.eq(src.files[1].left, vim.fs.normalize(dir .. "/left.lua"), "left path")
    h.eq(src.files[1].right, vim.fs.normalize(dir .. "/right.lua"), "right path")

    h.cleanup(dir)
  end,
}
