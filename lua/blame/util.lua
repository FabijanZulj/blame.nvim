local M = {}
M.nsId = nil

M.scroll_to_same_position = function(win_source, win_target)
	local win_line_source = vim.fn.line("w0", win_source)
	local scrolloff = vim.api.nvim_get_option("scrolloff")
	vim.api.nvim_win_set_cursor(win_target, { win_line_source + scrolloff, 0 })
	vim.api.nvim_win_call(win_target, function()
		vim.cmd("normal! zt")
	end)
end

---Calculates the longest string in the string[]
---@param string_array string[]
---@return integer
M.longest_string_in_array = function(string_array)
	local longest = 0
	for _, value in ipairs(string_array) do
		if string.len(value) > longest then
			longest = string.len(value)
		end
	end
	return longest
end

return M
