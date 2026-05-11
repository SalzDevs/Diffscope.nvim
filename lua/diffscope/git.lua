local M = {}

local function systemlist(cmd)
  local output = vim.fn.systemlist(cmd)
  local code = vim.v.shell_error
  return code == 0, output, code
end

local function normalize_path(path)
  if not path or path == "" then
    return nil
  end
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

function M.root(start)
  start = normalize_path(start or vim.api.nvim_buf_get_name(0)) or vim.uv.cwd()
  local dir = vim.fn.isdirectory(start) == 1 and start or vim.fs.dirname(start)
  local ok, output = systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
  if not ok or not output[1] or output[1] == "" then
    return nil
  end
  return vim.fs.normalize(output[1])
end

function M.relative(root, path)
  path = normalize_path(path)
  if not path then
    return nil
  end
  local rel = vim.fn.fnamemodify(path, ":.")
  if root and vim.startswith(path, root) then
    rel = path:sub(#root + 2)
  end
  return rel:gsub("\\", "/")
end

local function parse_status_line(line)
  if line == "" then
    return nil
  end

  local index = line:sub(1, 1)
  local worktree = line:sub(2, 2)
  local raw_path = vim.trim(line:sub(4))
  local old_path, new_path = raw_path:match("^(.-)%s%->%s(.+)$")
  local path = new_path or raw_path
  local status = worktree ~= " " and worktree or index

  if index == "?" and worktree == "?" then
    status = "?"
  end

  return {
    path = path,
    old_path = old_path,
    status = status,
    index_status = index,
    worktree_status = worktree,
  }
end

local function parse_name_status(lines)
  local files = {}
  for _, line in ipairs(lines) do
    if line ~= "" then
      local fields = vim.split(line, "\t")
      local status = fields[1]
      local path = fields[#fields]
      table.insert(files, {
        path = path,
        old_path = #fields > 2 and fields[2] or nil,
        status = status:sub(1, 1),
        index_status = status:sub(1, 1),
        worktree_status = " ",
      })
    end
  end
  return files
end

function M.changed_files(root, mode)
  mode = mode or "working"
  if mode == "staged" then
    local ok, output = systemlist({ "git", "-C", root, "diff", "--cached", "--name-status" })
    if not ok then
      return {}, output
    end
    return parse_name_status(output)
  end

  local ok, output = systemlist({ "git", "-C", root, "status", "--short" })
  if not ok then
    return {}, output
  end

  local files = {}
  for _, line in ipairs(output) do
    local file = parse_status_line(line)
    if file then
      table.insert(files, file)
    end
  end
  return files
end

function M.diff(root, path, mode)
  mode = mode or "working"
  local cmd

  if mode == "staged" then
    cmd = { "git", "-C", root, "diff", "--cached", "--no-color", "--", path }
  else
    cmd = { "git", "-C", root, "diff", "--no-color", "--", path }
  end

  local ok, output = systemlist(cmd)
  if ok and #output > 0 then
    return output
  end

  if mode == "working" then
    local absolute = root .. "/" .. path
    if vim.fn.filereadable(absolute) == 1 then
      local untracked = vim.fn.systemlist({ "git", "-C", root, "diff", "--no-color", "--no-index", "--", "/dev/null", absolute })
      if #untracked > 0 then
        return untracked
      end
    end
  end

  return output
end

function M.stage(root, path)
  local ok, output = systemlist({ "git", "-C", root, "add", "--", path })
  return ok, output
end

function M.reset(root, file)
  if file.index_status == "?" and file.worktree_status == "?" then
    local absolute = root .. "/" .. file.path
    local ok, err = pcall(vim.fn.delete, absolute)
    return ok and err == 0, { absolute }
  end

  local ok, output = systemlist({ "git", "-C", root, "checkout", "--", file.path })
  return ok, output
end

function M.read_head(root, path)
  local ok, output = systemlist({ "git", "-C", root, "show", "HEAD:" .. path })
  if not ok then
    return { "" }
  end
  return output
end

function M.read_index(root, path)
  local ok, output = systemlist({ "git", "-C", root, "show", ":" .. path })
  if not ok then
    return M.read_head(root, path)
  end
  return output
end

function M.read_worktree(root, path)
  local absolute = root .. "/" .. path
  if vim.fn.filereadable(absolute) ~= 1 then
    return { "" }
  end
  return vim.fn.readfile(absolute)
end

return M
