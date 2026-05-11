local config = require("diffscope.config")
local git = require("diffscope.git")
local highlights = require("diffscope.highlights")
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

local function create_base_buffer(name, lines, filetype)
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

local function filetype_for(path)
  return vim.filetype.match({ filename = path }) or ""
end

local function readfile_or_empty(path)
  if vim.fn.filereadable(path) == 1 then
    return vim.fn.readfile(path)
  end
  return { "" }
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

local function base_lines_for(diff_source, file)
  if diff_source.kind == "files" then
    return readfile_or_empty(file.left), file.left, file.right
  end

  if file.status == "?" then
    return { "" }, "Git index:/dev/null", diff_source.root .. "/" .. file.path
  end

  local base = diff_source.mode == "staged" and git.read_head(diff_source.root, file.path)
    or git.read_index(diff_source.root, file.path)
  return base, "Git base:" .. file.path, diff_source.root .. "/" .. file.path
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

local function diff_winhighlight()
  return table.concat({
    "DiffAdd:DiffscopeAdded",
    "DiffDelete:DiffscopeRemoved",
    "DiffChange:DiffscopeChanged",
    "DiffText:DiffscopeChangedText",
  }, ",")
end

local function tune_window(win, role, path)
  if not valid_win(win) then
    return
  end

  vim.wo[win].wrap = false
  vim.wo[win].foldenable = false
  vim.wo[win].cursorline = true
  vim.wo[win].signcolumn = "yes"
  vim.wo[win].winhighlight = diff_winhighlight()

  if role == "base" then
    vim.wo[win].winbar = " 󰦛 Before / read-only: " .. path
  else
    vim.wo[win].winbar = " 󰏫 Now / edit this file: " .. path
  end
end

local function apply_diff_options()
  state.old_diffopt = vim.o.diffopt
  vim.o.diffopt = table.concat({
    "internal",
    "filler",
    "closeoff",
    "algorithm:histogram",
    "indent-heuristic",
    "linematch:60",
    "context:99999",
  }, ",")
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

local function setup_mappings(buf)
  local mappings = config.options.mappings
  map(buf, mappings.close, M.close, "Close Diffscope")
  map(buf, mappings.help, M.toggle_help, "Diffscope help")
  map(buf, mappings.next_hunk, M.next_hunk, "Next hunk")
  map(buf, mappings.prev_hunk, M.prev_hunk, "Previous hunk")
  map(buf, mappings.stage_file, M.stage_file, "Stage current file")
  map(buf, mappings.reset_file, M.reset_file, "Reset current file")
end

local function help_lines()
  return {
    "Diffscope live file diff",
    "",
    "The right pane is the real file buffer. Edit it directly.",
    "The left pane is a read-only base copy.",
    "",
    "Green background  added/new lines",
    "Red background    removed/old lines",
    "",
    "]c / [c          next / previous hunk",
    "s                stage this file",
    "r                reset this file, with confirmation",
    "q                close diff mode, keep editing the file",
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

  local buf = create_base_buffer("Diffscope://help", help_lines(), "")
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

function M.next_hunk()
  vim.cmd("normal! ]c")
end

function M.prev_hunk()
  vim.cmd("normal! [c")
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

  notify("Reset " .. state.file.path)
end

function M.close()
  if not state then
    return
  end

  local old_state = state
  clear_mappings()

  if old_state.old_diffopt then
    vim.o.diffopt = old_state.old_diffopt
  end

  if valid_win(old_state.help_win) then
    pcall(vim.api.nvim_win_close, old_state.help_win, true)
  end

  for _, win in ipairs({ old_state.base_win, old_state.edit_win }) do
    if valid_win(win) then
      vim.api.nvim_win_call(win, function()
        pcall(vim.cmd, "diffoff")
        vim.wo.winhighlight = ""
        vim.wo.winbar = ""
        vim.wo.foldenable = true
      end)
    end
  end

  if valid_win(old_state.base_win) then
    pcall(vim.api.nvim_win_close, old_state.base_win, true)
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

  local base_lines, base_name, edit_path = base_lines_for(diff_source, file)
  local edit_label = diff_source.kind == "files" and file.right or file.path
  local ft = filetype_for(edit_path)

  state = {
    args = args or {},
    source = diff_source,
    file = file,
    previous_win = vim.api.nvim_get_current_win(),
    mapped_buffers = {},
  }

  local edit_buf = open_edit_buffer(edit_path)
  local edit_win = vim.api.nvim_get_current_win()
  local base_buf = create_base_buffer("Diffscope://base/" .. edit_label, base_lines, ft)

  vim.cmd("leftabove vertical new")
  local base_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(base_win, base_buf)

  if config.options.layout.base_width then
    vim.api.nvim_win_set_width(base_win, tonumber(config.options.layout.base_width))
  else
    vim.cmd("wincmd =")
  end

  state.base_win = base_win
  state.base_buf = base_buf
  state.edit_win = edit_win
  state.edit_buf = edit_buf

  apply_diff_options()
  tune_window(base_win, "base", base_name)
  tune_window(edit_win, "edit", edit_label)

  vim.api.nvim_set_current_win(base_win)
  vim.cmd("diffthis")
  vim.api.nvim_set_current_win(edit_win)
  vim.cmd("diffthis")

  setup_mappings(base_buf)
  setup_mappings(edit_buf)

  notify("Editing live diff for " .. edit_label)
end

return M
