local test_files = {
  "tests.e2e.config_test",
  "tests.e2e.git_source_test",
  "tests.e2e.ui_open_test",
  "tests.e2e.picker_test",
  "tests.e2e.reload_test",
  "tests.e2e.actions_test",
}

local failures = {}
local total = 0

for _, module in ipairs(test_files) do
  package.loaded[module] = nil
  local ok, tests = pcall(require, module)
  if not ok then
    table.insert(failures, module .. " failed to load:\n" .. tests)
  else
    for name, fn in pairs(tests) do
      total = total + 1
      local test_name = module .. " :: " .. name
      local case_ok, err = xpcall(fn, debug.traceback)
      pcall(function()
        require("diffscope").close()
      end)
      if #vim.api.nvim_list_tabpages() > 1 then
        pcall(vim.cmd, "silent! tabonly!")
      end
      if case_ok then
        print("PASS " .. test_name)
      else
        print("FAIL " .. test_name)
        table.insert(failures, test_name .. "\n" .. err)
      end
    end
  end
end

if #failures > 0 then
  print(string.format("\n%d/%d tests failed", #failures, total))
  print(table.concat(failures, "\n\n"))
  os.exit(1)
end

print(string.format("\n%d tests passed", total))
