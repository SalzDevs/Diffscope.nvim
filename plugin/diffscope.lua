if vim.g.loaded_diffscope == 1 then
  return
end
vim.g.loaded_diffscope = 1

vim.api.nvim_create_user_command("DiffScope", function(command)
  require("diffscope").open(command.fargs)
end, {
  nargs = "*",
  complete = "file",
  desc = "Open a focused diff review workspace",
})
