local git = require("diffscope.git")

local M = {}

local function current_file_source()
  local path = vim.api.nvim_buf_get_name(0)
  local root = git.root(path)
  if not root then
    return nil, "Current buffer is not inside a Git repository"
  end

  local rel = git.relative(root, path)
  return {
    kind = "git",
    mode = "working",
    root = root,
    title = "Current file",
    files = {
      {
        path = rel,
        status = "M",
        index_status = " ",
        worktree_status = "M",
      },
    },
  }
end

local function file_compare_source(args)
  local left = vim.fs.normalize(vim.fn.fnamemodify(args[1], ":p"))
  local right = vim.fs.normalize(vim.fn.fnamemodify(args[2], ":p"))

  return {
    kind = "files",
    title = "File compare",
    files = {
      {
        path = vim.fn.fnamemodify(left, ":t") .. " ↔ " .. vim.fn.fnamemodify(right, ":t"),
        status = "≠",
        left = left,
        right = right,
      },
    },
  }
end

local function git_source(args)
  local mode = args[1] == "staged" and "staged" or "working"
  local root = git.root()
  if not root then
    return nil, "Not inside a Git repository"
  end

  local files, err = git.changed_files(root, mode)
  if err and #err > 0 then
    return nil, table.concat(err, "\n")
  end

  return {
    kind = "git",
    mode = mode,
    root = root,
    title = mode == "staged" and "Staged changes" or "Working tree",
    files = files,
  }
end

function M.from_args(args)
  args = args or {}

  if #args == 1 and args[1] == "%" then
    return current_file_source()
  end

  if #args == 2 then
    return file_compare_source(args)
  end

  return git_source(args)
end

return M
