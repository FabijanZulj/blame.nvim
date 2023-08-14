vim.api.nvim_create_user_command("ToggleBlame", require("blame").toggle, { nargs = "*" })
