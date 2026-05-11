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
  return source.from_args(args or {})
end

local function choose_file_index(diff_source)
  if not diff_source or #diff_source.files == 0 then
    return nil
  end

  if diff_source.kind == "git" then
    local current = vim.api.nvim_buf_get_name(0)
    local rel = git.relative(diff_source.root, current)
    if rel then
      for index, file in ipairs(diff_source.files) do
        if file.path == rel then
          return index
        end
      end
    end
  end

  return 1
end

local function status_label(file)
  local status = file.status or " "
  if status == "?" then
    return "??"
  end
  if #status == 1 then
    return " " .. status
  end
  return status:sub(1, 2)
end

local function file_label(file)
  return string.format("%s  %s", status_label(file), file.path)
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
    "f                changed files picker",
    "]f / [f          next / previous changed file",
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
  map(buf, mappings.files, M.open_file_picker, "Diffscope changed files")
  map(buf, mappings.next_file, M.next_file, "Next changed file")
  map(buf, mappings.prev_file, M.prev_file, "Previous changed file")
  map(buf, mappings.stage_file, M.stage_file, "Stage current file")
  map(buf, mappings.reset_file, M.reset_file, "Reset current file")
end

local function install_write_autocmd()
  if state.autocmd then
    pcall(vim.api.nvim_del_autocmd, state.autocmd)
    state.autocmd = nil
  end

  state.autocmd = vim.api.nvim_create_autocmd("BufWritePost", {
    buffer = state.edit_buf,
    callback = function()
      refresh_diff()
    end,
    desc = "Refresh Diffscope diff viewer after write",
  })
end

local function close_picker()
  if state and valid_win(state.picker_win) then
    pcall(vim.api.nvim_win_close, state.picker_win, true)
  end
  if state then
    state.picker_win = nil
    state.picker_buf = nil
  end
end

local function prepare_file_switch()
  if not state or not valid_buf(state.edit_buf) or not vim.bo[state.edit_buf].modified then
    return true
  end

  local answer = vim.fn.confirm("Save changes before switching files?", "&Write\n&Discard\n&Cancel", 1)
  if answer == 1 then
    vim.api.nvim_buf_call(state.edit_buf, function()
      vim.cmd("write")
    end)
    return true
  elseif answer == 2 then
    vim.api.nvim_buf_call(state.edit_buf, function()
      vim.cmd("edit!")
    end)
    return true
  end

  return false
end

function M.open_file(index)
  if not state or not index or not state.files[index] then
    return
  end

  if index == state.file_index then
    close_picker()
    if valid_win(state.edit_win) then
      vim.api.nvim_set_current_win(state.edit_win)
    end
    return
  end

  if not prepare_file_switch() then
    return
  end

  close_picker()

  if valid_win(state.edit_win) then
    vim.api.nvim_set_current_win(state.edit_win)
  end

  state.file_index = index
  state.file = state.files[index]

  local edit_path, edit_label = edit_path_for(state.source, state.file)
  local edit_buf = open_edit_buffer(edit_path)

  state.edit_buf = edit_buf
  state.edit_win = vim.api.nvim_get_current_win()

  vim.bo[state.viewer_buf].filetype = vim.bo[edit_buf].filetype
  vim.api.nvim_buf_set_name(state.viewer_buf, "Diffscope://diff/" .. edit_label)
  tune_viewer_window(state.viewer_win, state.edit_win, edit_label)
  setup_mappings(edit_buf)
  install_write_autocmd()
  refresh_diff()

  if valid_win(state.edit_win) then
    vim.api.nvim_set_current_win(state.edit_win)
  end

  notify(string.format("Diffscope file %d/%d: %s", state.file_index, #state.files, edit_label))
end

function M.next_file()
  if not state or not state.files or #state.files == 0 then
    return
  end

  local next_index = state.file_index + 1
  if next_index > #state.files then
    next_index = 1
  end
  M.open_file(next_index)
end

function M.prev_file()
  if not state or not state.files or #state.files == 0 then
    return
  end

  local prev_index = state.file_index - 1
  if prev_index < 1 then
    prev_index = #state.files
  end
  M.open_file(prev_index)
end

function M.open_file_picker()
  if not state or not state.files then
    return
  end

  if valid_win(state.picker_win) then
    close_picker()
    return
  end

  local lines = {}
  for index, file in ipairs(state.files) do
    local prefix = index == state.file_index and "➜ " or "  "
    table.insert(lines, prefix .. file_label(file))
  end

  local buf = create_diff_viewer("Diffscope://files", lines, "")
  local width = math.min(70, math.max(36, math.floor(vim.o.columns * 0.45)))
  local height = math.min(math.max(#lines, 1), math.max(1, vim.o.lines - 8))

  state.picker_buf = buf
  state.picker_win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    style = "minimal",
    border = "rounded",
    title = " Changed files ",
    title_pos = "center",
  })

  vim.wo[state.picker_win].cursorline = true
  vim.api.nvim_win_set_cursor(state.picker_win, { state.file_index, 0 })
  vim.keymap.set("n", "q", close_picker, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "<Esc>", close_picker, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "<CR>", function()
    local selected = vim.api.nvim_win_get_cursor(state.picker_win)[1]
    M.open_file(selected)
  end, { buffer = buf, silent = true, nowait = true })
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

  if valid_win(old_state.picker_win) then
    pcall(vim.api.nvim_win_close, old_state.picker_win, true)
  end

  local can_close_tab = old_state.tab
    and vim.api.nvim_tabpage_is_valid(old_state.tab)
    and #vim.api.nvim_list_tabpages() > 1
    and (not valid_buf(old_state.edit_buf) or not vim.bo[old_state.edit_buf].modified)

  if can_close_tab then
    vim.api.nvim_set_current_tabpage(old_state.tab)
    pcall(vim.cmd, "tabclose")
    if old_state.previous_tab and vim.api.nvim_tabpage_is_valid(old_state.previous_tab) then
      vim.api.nvim_set_current_tabpage(old_state.previous_tab)
    end
  else
    if valid_win(old_state.viewer_win) then
      pcall(vim.api.nvim_win_close, old_state.viewer_win, true)
    end

    if valid_win(old_state.edit_win) then
      vim.api.nvim_set_current_win(old_state.edit_win)
    end
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

  local file_index = choose_file_index(diff_source)
  if not file_index then
    notify("No file available to diff", vim.log.levels.INFO)
    return
  end

  local file = diff_source.files[file_index]
  local edit_path, edit_label = edit_path_for(diff_source, file)
  local previous_tab = vim.api.nvim_get_current_tabpage()

  vim.cmd("tabnew")
  local tab = vim.api.nvim_get_current_tabpage()

  state = {
    args = args or {},
    source = diff_source,
    files = diff_source.files,
    file_index = file_index,
    file = file,
    previous_tab = previous_tab,
    tab = tab,
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

  install_write_autocmd()

  vim.api.nvim_set_current_win(edit_win)
  notify("Diff viewer opened for " .. edit_label)
end

return M
