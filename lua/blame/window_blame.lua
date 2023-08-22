local util = require("blame.util")
local highlights = require("blame.highlights")
local git = require("blame.git")

local M = {}
M.blame_window = nil
M.blame_buffer = nil
M.original_window = nil
M.gshow_output = nil

---Sets the autocommands for the blame buffer
local function setup_autocmd(blame_buff)
	vim.api.nvim_create_autocmd({ "BufHidden", "BufUnload" }, {
		callback = function()
			if M.blame_buffer ~= nil then
				M.reset_to_closed_state()
			end
		end,
		buffer = blame_buff,
		group = "BlameNvim",
		desc = "Reset state to closed when the buffer is exited.",
	})
end

---Sets the keybinds for the blame buffer
local function setup_keybinds(buff)
	vim.keymap.set("n", "q", ":q<cr>", { buffer = buff, nowait = true, silent = true, noremap = true })
	vim.keymap.set("n", "<esc>", ":q<cr>", { buffer = buff, nowait = true, silent = true, noremap = true })
	vim.keymap.set(
		"n",
		"<cr>",
		[[:lua require("blame.window_blame").show_full_commit()<cr>]],
		{ buffer = buff, nowait = true, silent = true, noremap = true }
	)
end

M.window_blame = function(blame_lines, config)
	local width = config["width"] or (util.longest_string_in_array(blame_lines) + 8)
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	M.original_window = vim.api.nvim_get_current_win()

	vim.cmd("lefta vs")
	M.blame_window = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_width(M.blame_window, width)
	M.blame_buffer = vim.api.nvim_create_buf(false, true)

	vim.api.nvim_win_set_buf(M.blame_window, M.blame_buffer)
	vim.api.nvim_buf_set_lines(M.blame_buffer, 0, -1, false, blame_lines)
	vim.api.nvim_buf_set_option(M.blame_buffer, "filetype", "blame")

	util.scroll_to_same_position(M.original_window, M.blame_window)

	setup_keybinds(M.blame_buffer)
	setup_autocmd(M.blame_buffer)

	vim.api.nvim_win_set_cursor(M.blame_window, cursor_pos)

	vim.api.nvim_set_option_value("cursorbind", true, { win = M.original_window })
	vim.api.nvim_set_option_value("scrollbind", true, { win = M.original_window })
	vim.api.nvim_set_option_value("cursorline", true, { win = M.original_window })

	vim.api.nvim_set_option_value("cursorbind", true, { win = M.blame_window })
	vim.api.nvim_set_option_value("scrollbind", true, { win = M.blame_window })
	vim.api.nvim_set_option_value("cursorline", true, { win = M.blame_window })

	vim.api.nvim_set_current_win(M.original_window)
	highlights.highlight_same_hash(M.blame_buffer)
	vim.api.nvim_buf_set_option(M.blame_buffer, "modifiable", false)
end

---Git show command done callback
---@param _ any
---@param status any exit status of command
local function show_done(_, status)
	if status == 0 and M.gshow_output ~= nil then
		local hash = M.gshow_output[1]:match("commit (%S+)")
		local gshow_buff = vim.api.nvim_create_buf(true, true)
		vim.api.nvim_set_current_win(M.original_window)

		vim.api.nvim_buf_set_lines(gshow_buff, 0, -1, false, M.gshow_output)
		vim.api.nvim_buf_set_option(gshow_buff, "filetype", "git")
		vim.api.nvim_buf_set_name(gshow_buff, hash)
		vim.api.nvim_buf_set_option(gshow_buff, "readonly", true)
		vim.api.nvim_set_current_buf(gshow_buff)
		vim.api.nvim_win_set_buf(M.original_window, gshow_buff)
		M.close_window()
	else
		vim.notify("Could not open full commit info", vim.log.levels.INFO)
	end
end

---Output of git show
---@param _ any
---@param gshow_output any stdout output of git show
local function show_output(_, gshow_output)
	M.gshow_output = gshow_output
end

---Get git show output for hash under cursor
M.show_full_commit = function()
	local row, _ = unpack(vim.api.nvim_win_get_cursor(M.blame_window))
	local blame_line = vim.api.nvim_buf_get_lines(M.blame_buffer, row - 1, row, false)[1]
	local hash = blame_line:match("^%S+")
	git.show(hash, vim.fn.getcwd(), show_done, show_output)
end

---Close the blame window
M.close_window = function()
	local buff = M.blame_buffer
	vim.api.nvim_win_close(M.blame_window, true)
	vim.api.nvim_buf_delete(buff, { force = true })
end

---Reset the state to initial/closed state
M.reset_to_closed_state = function()
	vim.api.nvim_set_option_value("cursorbind", false, { win = M.original_window })
	vim.api.nvim_set_option_value("scrollbind", false, { win = M.original_window })
	M.original_window = nil
	M.blame_window = nil
	M.blame_buffer = nil
end

M.is_window_open = function()
	return M.blame_window ~= nil and vim.api.nvim_win_is_valid(M.blame_window)
end

return M
