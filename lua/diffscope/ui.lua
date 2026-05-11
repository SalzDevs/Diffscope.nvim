local config = require("diffscope.config")
local git = require("diffscope.git")
local source = require("diffscope.source")

local M = {}

local state = nil

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Diffscope" })
end

local function valid_win(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function create_scratch(name, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = filetype or ""
  vim.api.nvim_buf_set_name(buf, name)
  return buf
end

local function set_lines(buf, lines)
  if not valid_buf(buf) then
    return
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function map(buf, lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, nowait = true, desc = desc })
end

local function selected_file()
  if not state or not valid_win(state.file_win) then
    return nil
  end

  if #state.source.files == 0 then
    return nil
  end

  local line = vim.api.nvim_win_get_cursor(state.file_win)[1]
  return state.source.files[line]
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

local function render_file_list()
  if not state or not valid_buf(state.file_buf) then
    return
  end

  local lines = {}
  if #state.source.files == 0 then
    lines = { " No changes", "", " Press q to close" }
  else
    for _, file in ipairs(state.source.files) do
      table.insert(lines, string.format("%s  %s", status_label(file), file.path))
    end
  end

  set_lines(state.file_buf, lines)
end

local function help_lines()
  return {
    "Diffscope help",
    "",
    "j/k       move in file list",
    "<CR>      open side-by-side diff",
    "p         preview unified diff",
    "]c / [c   next / previous hunk",
    "s         stage selected file",
    "r         reset selected file, with confirmation",
    "?         toggle this help",
    "q         close Diffscope",
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

  local buf = create_scratch("Diffscope://help", "")
  set_lines(buf, help_lines())

  local width = 48
  local height = #help_lines() + 2
  local ui = vim.api.nvim_list_uis()[1]
  state.help_win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((ui.height - height) / 2),
    col = math.floor((ui.width - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " Diffscope ",
    title_pos = "center",
  })

  map(buf, "q", M.toggle_help, "Close help")
  map(buf, "?", M.toggle_help, "Close help")
end

local function preview_lines_for(file)
  if state.source.kind == "files" then
    return vim.fn.systemlist({ "git", "diff", "--no-color", "--no-index", "--", file.left, file.right })
  end

  local lines = git.diff(state.source.root, file.path, state.source.mode)
  if #lines == 0 then
    return { "No unstaged diff for " .. file.path, "", "Try :DiffScope staged for staged changes." }
  end
  return lines
end

function M.preview()
  local file = selected_file()
  if not file or not valid_buf(state.diff_buf) then
    return
  end

  if valid_win(state.diff_win) then
    vim.api.nvim_set_current_win(state.diff_win)
  end

  vim.wo[state.diff_win].diff = false
  vim.bo[state.diff_buf].filetype = "diff"
  set_lines(state.diff_buf, preview_lines_for(file))
end

local function close_right_windows()
  if not state then
    return
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(state.tab)) do
    if win ~= state.file_win and valid_win(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

local function buffer_from_lines(name, lines, filetype)
  local buf = create_scratch(name, filetype)
  set_lines(buf, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  return buf
end

local function filetype_for(path)
  local ft = vim.filetype.match({ filename = path })
  return ft or ""
end

local function split_buffers_for(file)
  if state.source.kind == "files" then
    return buffer_from_lines(file.left, vim.fn.readfile(file.left), filetype_for(file.left)),
      buffer_from_lines(file.right, vim.fn.readfile(file.right), filetype_for(file.right))
  end

  local root = state.source.root
  local left = state.source.mode == "staged" and git.read_head(root, file.path)
    or git.read_index(root, file.path)
  local right = state.source.mode == "staged" and git.read_index(root, file.path)
    or git.read_worktree(root, file.path)
  local ft = filetype_for(file.path)

  return buffer_from_lines("Diffscope://base/" .. file.path, left, ft),
    buffer_from_lines("Diffscope://current/" .. file.path, right, ft)
end

local function apply_diff_options()
  state.old_diffopt = vim.o.diffopt
  local diffopt = {
    "internal",
    "filler",
    "closeoff",
    "algorithm:histogram",
    "indent-heuristic",
    "linematch:60",
  }
  vim.o.diffopt = table.concat(diffopt, ",")
end

function M.open_split()
  local file = selected_file()
  if not file then
    return
  end

  close_right_windows()
  apply_diff_options()

  vim.api.nvim_set_current_win(state.file_win)
  vim.cmd("rightbelow vertical new")
  local left_win = vim.api.nvim_get_current_win()
  local left_buf, right_buf = split_buffers_for(file)
  vim.api.nvim_win_set_buf(left_win, left_buf)

  vim.cmd("rightbelow vertical new")
  local right_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(right_win, right_buf)

  vim.api.nvim_set_current_win(left_win)
  vim.cmd("diffthis")
  vim.api.nvim_set_current_win(right_win)
  vim.cmd("diffthis")

  state.diff_win = right_win
  state.diff_buf = right_buf

  map(left_buf, config.options.mappings.close, M.close, "Close Diffscope")
  map(right_buf, config.options.mappings.close, M.close, "Close Diffscope")
  map(left_buf, config.options.mappings.help, M.toggle_help, "Diffscope help")
  map(right_buf, config.options.mappings.help, M.toggle_help, "Diffscope help")
end

local function refresh_source()
  local new_source, err = source.from_args(state.args)
  if not new_source then
    notify(err, vim.log.levels.ERROR)
    return
  end
  state.source = new_source
  render_file_list()
  if #state.source.files > 0 then
    vim.api.nvim_win_set_cursor(state.file_win, { 1, 0 })
    M.preview()
  else
    set_lines(state.diff_buf, { "No changes" })
  end
end

function M.stage_file()
  local file = selected_file()
  if not file or state.source.kind ~= "git" then
    return
  end

  local ok, output = git.stage(state.source.root, file.path)
  if not ok then
    notify(table.concat(output, "\n"), vim.log.levels.ERROR)
    return
  end

  notify("Staged " .. file.path)
  refresh_source()
end

function M.reset_file()
  local file = selected_file()
  if not file or state.source.kind ~= "git" then
    return
  end

  local answer = vim.fn.confirm("Reset " .. file.path .. "?", "&Reset\n&Cancel", 2)
  if answer ~= 1 then
    return
  end

  local ok, output = git.reset(state.source.root, file)
  if not ok then
    notify(table.concat(output, "\n"), vim.log.levels.ERROR)
    return
  end

  notify("Reset " .. file.path)
  refresh_source()
end

function M.next_hunk()
  local win = vim.api.nvim_get_current_win()
  if vim.wo[win].diff then
    vim.cmd("normal! ]c")
    return
  end
  vim.fn.search("^@@", "W")
end

function M.prev_hunk()
  local win = vim.api.nvim_get_current_win()
  if vim.wo[win].diff then
    vim.cmd("normal! [c")
    return
  end
  vim.fn.search("^@@", "bW")
end

local function setup_mappings(buf)
  local mappings = config.options.mappings
  map(buf, mappings.close, M.close, "Close Diffscope")
  map(buf, mappings.help, M.toggle_help, "Diffscope help")
  map(buf, mappings.preview, M.preview, "Preview unified diff")
  map(buf, mappings.open_split, M.open_split, "Open side-by-side diff")
  map(buf, mappings.next_hunk, M.next_hunk, "Next hunk")
  map(buf, mappings.prev_hunk, M.prev_hunk, "Previous hunk")
  map(buf, mappings.stage_file, M.stage_file, "Stage file")
  map(buf, mappings.reset_file, M.reset_file, "Reset file")
end

function M.close()
  if not state then
    return
  end

  if state.old_diffopt then
    vim.o.diffopt = state.old_diffopt
  end

  if valid_win(state.help_win) then
    pcall(vim.api.nvim_win_close, state.help_win, true)
  end

  local tab = state.tab
  local previous = state.previous_tab
  state = nil

  if tab and vim.api.nvim_tabpage_is_valid(tab) then
    if #vim.api.nvim_list_tabpages() > 1 then
      vim.api.nvim_set_current_tabpage(tab)
      vim.cmd("tabclose")
    else
      vim.cmd("diffoff!")
      vim.cmd("enew")
    end
  end

  if previous and vim.api.nvim_tabpage_is_valid(previous) then
    vim.api.nvim_set_current_tabpage(previous)
  end
end

function M.open(args)
  if state then
    M.close()
  end

  local diff_source, err = source.from_args(args)
  if not diff_source then
    notify(err, vim.log.levels.ERROR)
    return
  end

  local previous_tab = vim.api.nvim_get_current_tabpage()
  vim.cmd("tabnew")
  local tab = vim.api.nvim_get_current_tabpage()

  local diff_buf = create_scratch("Diffscope://diff", "diff")
  vim.api.nvim_win_set_buf(0, diff_buf)
  local diff_win = vim.api.nvim_get_current_win()

  vim.cmd("topleft vertical " .. tonumber(config.options.layout.file_panel_width) .. "new")
  local file_win = vim.api.nvim_get_current_win()
  local file_buf = create_scratch("Diffscope://files", "")
  vim.api.nvim_win_set_buf(file_win, file_buf)
  vim.wo[file_win].number = false
  vim.wo[file_win].relativenumber = false
  vim.wo[file_win].signcolumn = "no"
  vim.wo[file_win].winfixwidth = true

  state = {
    args = args or {},
    previous_tab = previous_tab,
    tab = tab,
    source = diff_source,
    file_win = file_win,
    file_buf = file_buf,
    diff_win = diff_win,
    diff_buf = diff_buf,
  }

  setup_mappings(file_buf)
  setup_mappings(diff_buf)
  render_file_list()

  if #diff_source.files > 0 then
    M.preview()
    if config.options.view.default == "split" then
      M.open_split()
    end
  else
    set_lines(diff_buf, { "No changes", "", diff_source.title })
  end
end

return M
