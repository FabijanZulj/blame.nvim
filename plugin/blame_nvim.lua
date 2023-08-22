vim.api.nvim_create_user_command("ToggleBlame", function(args)
	require("blame").toggle(args)
end, { nargs = "*" })

vim.api.nvim_create_user_command("EnableBlame", function(args)
	require("blame").enable(args)
end, { nargs = "*" })

vim.api.nvim_create_user_command("DisableBlame", function()
	require("blame").disable()
end, {})
