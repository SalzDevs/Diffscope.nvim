local M = {}

function M.eq(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s\nexpected: %s\nactual:   %s", message or "values differ", vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

function M.truthy(value, message)
  if not value then
    error(message or "expected truthy value", 2)
  end
end

function M.contains(haystack, needle, message)
  if not tostring(haystack):find(needle, 1, true) then
    error(string.format("%s\nexpected to find: %s\nin: %s", message or "missing substring", needle, tostring(haystack)), 2)
  end
end

function M.no_contains(haystack, needle, message)
  if tostring(haystack):find(needle, 1, true) then
    error(string.format("%s\ndid not expect to find: %s\nin: %s", message or "unexpected substring", needle, tostring(haystack)), 2)
  end
end

function M.run_git(dir, args)
  local cmd = { "git", "-C", dir }
  vim.list_extend(cmd, args)
  local output = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    error("git command failed: " .. table.concat(cmd, " ") .. "\n" .. table.concat(output, "\n"), 2)
  end
  return output
end

function M.write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines, path)
end

function M.temp_repo()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  M.run_git(dir, { "init" })
  M.run_git(dir, { "config", "user.name", "Diffscope Test" })
  M.run_git(dir, { "config", "user.email", "diffscope-test@example.com" })

  M.write(dir .. "/alpha.lua", {
    "local M = {}",
    "",
    "function M.alpha()",
    "  return 'alpha'",
    "end",
    "",
    "return M",
  })
  M.write(dir .. "/beta.lua", {
    "local M = {}",
    "",
    "function M.beta()",
    "  return 'beta'",
    "end",
    "",
    "return M",
  })

  M.run_git(dir, { "add", "." })
  M.run_git(dir, { "commit", "-m", "initial" })

  M.write(dir .. "/alpha.lua", {
    "local M = {}",
    "",
    "function M.alpha()",
    "  return 'alpha changed'",
    "end",
    "",
    "function M.added()",
    "  return true",
    "end",
    "",
    "return M",
  })
  M.write(dir .. "/beta.lua", {
    "local M = {}",
    "",
    "function M.beta()",
    "  return 'beta changed'",
    "end",
    "",
    "return M",
  })

  return dir
end

function M.cleanup(dir)
  if dir and dir ~= "" then
    vim.fn.delete(dir, "rf")
  end
end

function M.reset_diffscope_modules()
  for name in pairs(package.loaded) do
    if name == "diffscope" or name:match("^diffscope%.") then
      package.loaded[name] = nil
    end
  end
  vim.cmd("runtime plugin/diffscope.lua")
end

function M.close_diffscope()
  pcall(function()
    require("diffscope").close()
  end)
end

function M.current_tab_wins()
  return vim.api.nvim_tabpage_list_wins(0)
end

function M.find_win_by_bufname(pattern)
  for _, win in ipairs(M.current_tab_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    if name:find(pattern, 1, true) then
      return win, buf, name
    end
  end
  return nil
end

function M.buf_lines(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

function M.join_lines(lines)
  return table.concat(lines, "\n")
end

return M
