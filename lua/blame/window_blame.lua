local util = require("blame.util")
local highlights = require("blame.highlights")

local M = {}
M.blame_window = nil
M.blame_buffer = nil
M.original_window = nil

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

M.close_window = function()
	vim.api.nvim_win_close(M.blame_window, true)
	vim.api.nvim_buf_delete(M.blame_buffer, { force = true })
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
