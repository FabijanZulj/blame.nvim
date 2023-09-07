local M = {}

---Execute git blame line porcelain command
---@param filename string
---@param cwd any cwd where to execute the command
---@param on_exit any callback on exiting the command
---@param on_stdout any
M.blame = function(filename, cwd, on_exit, on_stdout)
	local blame_command = "git --no-pager blame --line-porcelain " .. filename
	vim.fn.jobstart(blame_command, {
		cwd = cwd,
		on_exit = on_exit,
		on_stdout = on_stdout,
		stdout_buffered = true,
	})
end

---Execute git show command
---@param hash string git object hash to get git show for
---@param file_path string|nil file to show
---@param cwd any cwd where to execute the command
---@param on_exit any callback on exiting the command
---@param on_stdout any
M.show = function(hash, file_path, cwd, on_exit, on_stdout)
	local show_command = "git --no-pager show " .. hash
	if file_path then
		show_command = show_command .. ":" .. file_path
	end
	print(cwd)
	print(show_command)
	vim.fn.jobstart(show_command, {
		cwd = cwd,
		on_exit = on_exit,
		on_stdout = on_stdout,
		stdout_buffered = true,
	})
end

return M
