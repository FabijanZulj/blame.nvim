local git = require("blame.git")
local M = {}
M.blame_stack = {}
M.gshow_output = nil

---Git show command done callback
local function show_done(bufId)
	return function(_, status)
		print(status)
		vim.api.nvim_buf_set_lines(bufId, 0, -1, false, M.gshow_output)
	end
end

---Output of git show
---@param _ any
---@param gshow_output any stdout output of git show
local function show_output(_, gshow_output)
	print(vim.inspect(gshow_output))
	M.gshow_output = gshow_output
end

M.push_to_blame_stack = function(orig_window, blame_win, blame_buf)
	local row, _ = unpack(vim.api.nvim_win_get_cursor(blame_win))
	local blame_line = vim.api.nvim_buf_get_lines(blame_buf, row - 1, row, false)[1]
	local hash = blame_line:match("^%S+")
	local orig_buf = vim.api.nvim_win_get_buf(orig_window)

	local full_filepath = vim.api.nvim_buf_get_name(orig_buf)
	local filename = full_filepath:match("([^/]+)$")
	local file_folder = full_filepath:match("(.-)[^%/]+$")

	git.show(hash, "./" .. filename, file_folder, show_done(orig_buf), show_output)
end

return M
