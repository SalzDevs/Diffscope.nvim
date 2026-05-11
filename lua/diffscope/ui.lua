local config = require("diffscope.config")
local git = require("diffscope.git")
local highlights = require("diffscope.highlights")
local source = require("diffscope.source")

local M = {}

local state = nil
local namespace = vim.api.nvim_create_namespace("diffscope")

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Diffscope" })
end

local function valid_win(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function set_lines(buf, lines)
  if not valid_buf(buf) then
    return
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function create_diff_viewer(name, lines, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, name)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = filetype or ""
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  return buf
end

local function resolve_source(args)
  args = args or {}

  if #args == 0 then
    local current = vim.api.nvim_buf_get_name(0)
    if current ~= "" and git.root(current) then
      local current_source = source.from_args({ "%" })
      if current_source then
        return current_source
      end
    end
  end

  return source.from_args(args)
end

local function choose_file(diff_source)
  if not diff_source or #diff_source.files == 0 then
    return nil
  end

  if diff_source.kind == "git" then
    local current = vim.api.nvim_buf_get_name(0)
    local rel = git.relative(diff_source.root, current)
    if rel then
      for _, file in ipairs(diff_source.files) do
        if file.path == rel then
          return file
        end
      end
    end
  end

  return diff_source.files[1]
end

local function edit_path_for(diff_source, file)
  if diff_source.kind == "files" then
    return file.right, file.right
  end

  return diff_source.root .. "/" .. file.path, file.path
end

local function open_edit_buffer(path)
  local current = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_get_name(current) == vim.fs.normalize(path) then
    return current
  end

  local buf = vim.fn.bufadd(path)
  vim.fn.bufload(buf)
  vim.api.nvim_win_set_buf(0, buf)
  return buf
end

local function diff_lines_for(diff_source, file)
  if diff_source.kind == "files" then
    local output = vim.fn.systemlist({ "git", "diff", "--no-color", "--no-index", "--", file.left, file.right })
    if #output == 0 then
      return { "No diff between files." }
    end
    return output
  end

  local lines = git.diff(diff_source.root, file.path, diff_source.mode)
  if #lines == 0 then
    if diff_source.mode == "staged" then
      return { "No staged diff for " .. file.path .. "." }
    end
    return { "No working tree diff for " .. file.path .. ".", "", "Save the file and run :DiffScope again." }
  end
  return lines
end

local function current_lines(buf)
  if not valid_buf(buf) then
    return { "" }
  end
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function append_rendered(rendered, kinds, text, kind)
  table.insert(rendered, text)
  table.insert(kinds, kind or "context")
end

local function render_code_diff(raw_lines, file_lines)
  local rendered = {}
  local kinds = {}
  local hunks = {}
  local new_cursor = 1
  local found_hunk = false
  local index = 1

  while index <= #raw_lines do
    local line = raw_lines[index]
    local old_start, old_count, new_start, new_count = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")

    if old_start and new_start then
      found_hunk = true
      new_start = tonumber(new_start)

      while new_cursor < new_start and new_cursor <= #file_lines do
        append_rendered(rendered, kinds, file_lines[new_cursor], "context")
        new_cursor = new_cursor + 1
      end

      local viewer_line = math.max(#rendered + 1, 1)
      index = index + 1

      while index <= #raw_lines do
        local hunk_line = raw_lines[index]
        if hunk_line:match("^@@") or hunk_line:match("^diff %-%-git") then
          break
        end

        local prefix = hunk_line:sub(1, 1)
        if prefix == " " then
          append_rendered(rendered, kinds, hunk_line:sub(2), "context")
          new_cursor = new_cursor + 1
        elseif prefix == "+" then
          append_rendered(rendered, kinds, hunk_line:sub(2), "added")
          new_cursor = new_cursor + 1
        elseif prefix == "-" then
          append_rendered(rendered, kinds, hunk_line:sub(2), "removed")
        end

        index = index + 1
      end

      table.insert(hunks, {
        viewer_line = viewer_line,
        old_start = tonumber(old_start),
        old_count = tonumber(old_count ~= "" and old_count or "1"),
        new_start = new_start,
        new_count = tonumber(new_count ~= "" and new_count or "1"),
      })
    else
      index = index + 1
    end
  end

  if not found_hunk then
    for _, line in ipairs(file_lines) do
      append_rendered(rendered, kinds, line, "context")
    end
    return rendered, kinds, {}
  end

  while new_cursor <= #file_lines do
    append_rendered(rendered, kinds, file_lines[new_cursor], "context")
    new_cursor = new_cursor + 1
  end

  return rendered, kinds, hunks
end

local function highlight_diff(buf, kinds)
  if not valid_buf(buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)

  for index, kind in ipairs(kinds) do
    local group = nil

    if kind == "added" then
      group = "DiffscopeAdded"
    elseif kind == "removed" then
      group = "DiffscopeRemoved"
    end

    if group then
      vim.api.nvim_buf_set_extmark(buf, namespace, index - 1, 0, {
        line_hl_group = group,
      })
    end
  end
end

local function refresh_diff()
  if not state or not valid_buf(state.viewer_buf) then
    return
  end

  local raw_lines = diff_lines_for(state.source, state.file)
  local rendered_lines, line_kinds, hunks = render_code_diff(raw_lines, current_lines(state.edit_buf))
  state.hunks = hunks
  set_lines(state.viewer_buf, rendered_lines)
  highlight_diff(state.viewer_buf, line_kinds)
end

local function tune_viewer_window(win, edit_win, _label)
  if not valid_win(win) then
    return
  end

  vim.wo[win].wrap = valid_win(edit_win) and vim.wo[edit_win].wrap or false
  vim.wo[win].foldenable = false
  vim.wo[win].number = valid_win(edit_win) and vim.wo[edit_win].number or true
  vim.wo[win].relativenumber = valid_win(edit_win) and vim.wo[edit_win].relativenumber or false
  vim.wo[win].cursorline = valid_win(edit_win) and vim.wo[edit_win].cursorline or true
  vim.wo[win].signcolumn = valid_win(edit_win) and vim.wo[edit_win].signcolumn or "yes"
  vim.wo[win].winbar = valid_win(edit_win) and vim.wo[edit_win].winbar or ""
end

local function map(buf, lhs, rhs, desc)
  if not lhs or lhs == "" then
    return
  end

  vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, nowait = true, desc = desc })
  state.mapped_buffers[buf] = state.mapped_buffers[buf] or {}
  table.insert(state.mapped_buffers[buf], lhs)
end

local function clear_mappings()
  if not state then
    return
  end

  for buf, mappings in pairs(state.mapped_buffers or {}) do
    if valid_buf(buf) then
      for _, lhs in ipairs(mappings) do
        pcall(vim.keymap.del, "n", lhs, { buffer = buf })
      end
    end
  end
end

local function help_lines()
  return {
    "Diffscope diff viewer + editor",
    "",
    "Left pane   read-only code view with diff colors",
    "Right pane  regular editable Neovim buffer",
    "",
    "Green background  added/new lines",
    "Red background    removed/old lines",
    "",
    "]c / [c          next / previous hunk",
    "s                write and stage this file",
    "r                reset this file, with confirmation",
    "q                close the diff viewer",
    "?                toggle this help",
  }
end

function M.toggle_help()
  if not state then
    return
  end

  if valid_win(state.help_win) then
    vim.api.nvim_win_close(state.help_win, true)
    state.help_win = nil
    return
  end

  local buf = create_diff_viewer("Diffscope://help", help_lines())
  vim.bo[buf].filetype = ""

  local width = 58
  local height = #help_lines() + 2
  local ui = vim.api.nvim_list_uis()[1]
  state.help_win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(0, math.floor((ui.height - height) / 2)),
    col = math.max(0, math.floor((ui.width - width) / 2)),
    style = "minimal",
    border = "rounded",
    title = " Diffscope ",
    title_pos = "center",
  })

  vim.keymap.set("n", "q", M.toggle_help, { buffer = buf, silent = true })
  vim.keymap.set("n", "?", M.toggle_help, { buffer = buf, silent = true })
end

local function goto_hunk(direction)
  if not state or not state.hunks or #state.hunks == 0 then
    return
  end

  local current_win = vim.api.nvim_get_current_win()
  local on_viewer = current_win == state.viewer_win
  local cursor_line = vim.api.nvim_win_get_cursor(current_win)[1]
  local target = nil

  if on_viewer then
    if direction > 0 then
      for _, hunk in ipairs(state.hunks) do
        if hunk.viewer_line > cursor_line then
          target = hunk
          break
        end
      end
      target = target or state.hunks[1]
    else
      for index = #state.hunks, 1, -1 do
        if state.hunks[index].viewer_line < cursor_line then
          target = state.hunks[index]
          break
        end
      end
      target = target or state.hunks[#state.hunks]
    end
  else
    if direction > 0 then
      for _, hunk in ipairs(state.hunks) do
        if hunk.new_start > cursor_line then
          target = hunk
          break
        end
      end
      target = target or state.hunks[1]
    else
      for index = #state.hunks, 1, -1 do
        if state.hunks[index].new_start < cursor_line then
          target = state.hunks[index]
          break
        end
      end
      target = target or state.hunks[#state.hunks]
    end
  end

  if not target then
    return
  end

  if valid_win(state.viewer_win) then
    vim.api.nvim_win_set_cursor(state.viewer_win, { target.viewer_line, 0 })
  end

  if valid_win(state.edit_win) then
    local edit_line_count = vim.api.nvim_buf_line_count(state.edit_buf)
    local edit_line = math.min(math.max(target.new_start, 1), edit_line_count)
    vim.api.nvim_win_set_cursor(state.edit_win, { edit_line, 0 })
  end

  if valid_win(current_win) then
    vim.api.nvim_set_current_win(current_win)
  end
end

function M.next_hunk()
  goto_hunk(1)
end

function M.prev_hunk()
  goto_hunk(-1)
end

function M.stage_file()
  if not state or state.source.kind ~= "git" then
    return
  end

  if valid_buf(state.edit_buf) and vim.bo[state.edit_buf].modified then
    vim.api.nvim_buf_call(state.edit_buf, function()
      vim.cmd("write")
    end)
  end

  local ok, output = git.stage(state.source.root, state.file.path)
  if not ok then
    notify(table.concat(output, "\n"), vim.log.levels.ERROR)
    return
  end

  refresh_diff()
  notify("Staged " .. state.file.path)
end

function M.reset_file()
  if not state or state.source.kind ~= "git" then
    return
  end

  local answer = vim.fn.confirm("Reset " .. state.file.path .. "?", "&Reset\n&Cancel", 2)
  if answer ~= 1 then
    return
  end

  local ok, output = git.reset(state.source.root, state.file)
  if not ok then
    notify(table.concat(output, "\n"), vim.log.levels.ERROR)
    return
  end

  if valid_buf(state.edit_buf) then
    vim.api.nvim_buf_call(state.edit_buf, function()
      vim.cmd("edit!")
    end)
  end

  refresh_diff()
  notify("Reset " .. state.file.path)
end

local function setup_mappings(buf)
  local mappings = config.options.mappings
  map(buf, mappings.close, M.close, "Close Diffscope")
  map(buf, mappings.help, M.toggle_help, "Diffscope help")
  map(buf, mappings.next_hunk, M.next_hunk, "Next hunk")
  map(buf, mappings.prev_hunk, M.prev_hunk, "Previous hunk")
  map(buf, mappings.stage_file, M.stage_file, "Stage current file")
  map(buf, mappings.reset_file, M.reset_file, "Reset current file")
end

function M.close()
  if not state then
    return
  end

  local old_state = state
  clear_mappings()

  if old_state.autocmd then
    pcall(vim.api.nvim_del_autocmd, old_state.autocmd)
  end

  if valid_win(old_state.help_win) then
    pcall(vim.api.nvim_win_close, old_state.help_win, true)
  end

  if valid_win(old_state.viewer_win) then
    pcall(vim.api.nvim_win_close, old_state.viewer_win, true)
  end

  if valid_win(old_state.edit_win) then
    vim.api.nvim_set_current_win(old_state.edit_win)
  end

  state = nil
end

function M.open(args)
  highlights.setup()

  if state then
    M.close()
  end

  local diff_source, err = resolve_source(args)
  if not diff_source then
    notify(err, vim.log.levels.ERROR)
    return
  end

  local file = choose_file(diff_source)
  if not file then
    notify("No file available to diff", vim.log.levels.INFO)
    return
  end

  local edit_path, edit_label = edit_path_for(diff_source, file)

  state = {
    args = args or {},
    source = diff_source,
    file = file,
    previous_win = vim.api.nvim_get_current_win(),
    hunks = {},
    mapped_buffers = {},
  }

  local edit_buf = open_edit_buffer(edit_path)
  local edit_win = vim.api.nvim_get_current_win()
  local raw_diff_lines = diff_lines_for(diff_source, file)
  local diff_lines, line_kinds, hunks = render_code_diff(raw_diff_lines, current_lines(edit_buf))
  state.hunks = hunks
  local viewer_buf = create_diff_viewer("Diffscope://diff/" .. edit_label, diff_lines, vim.bo[edit_buf].filetype)

  vim.cmd("leftabove vertical new")
  local viewer_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(viewer_win, viewer_buf)

  if config.options.layout.base_width then
    vim.api.nvim_win_set_width(viewer_win, tonumber(config.options.layout.base_width))
  else
    vim.cmd("wincmd =")
  end

  state.viewer_win = viewer_win
  state.viewer_buf = viewer_buf
  state.edit_win = edit_win
  state.edit_buf = edit_buf

  tune_viewer_window(viewer_win, edit_win, edit_label)
  highlight_diff(viewer_buf, line_kinds)
  setup_mappings(viewer_buf)
  setup_mappings(edit_buf)

  state.autocmd = vim.api.nvim_create_autocmd("BufWritePost", {
    buffer = edit_buf,
    callback = function()
      refresh_diff()
    end,
    desc = "Refresh Diffscope diff viewer after write",
  })

  vim.api.nvim_set_current_win(edit_win)
  notify("Diff viewer opened for " .. edit_label)
end

return M
