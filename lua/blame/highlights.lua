local M = {}
M.nsId = nil

---@return string
local function random_rgb()
	local r = math.random(100, 255)
	local g = math.random(100, 255)
	local b = math.random(100, 255)
	return string.format("#%02X%02X%02X", r, g, b)
end

---Creates the highlights for Hash, NotCommited and random color per one hash
---@param parsed_lines any
M.map_highlights_per_hash = function(parsed_lines)
	vim.cmd([[
    highlight DimHashBlame guifg=DimGray
    highlight NotCommitedBlame guifg=bg guibg=bg
  ]])

	for _, value in ipairs(parsed_lines) do
		local full_hash = value["hash"]
		local hash = string.sub(full_hash, 0, 8)
		if vim.fn.hlID(hash) == 0 then
			vim.cmd("highlight " .. hash .. " guifg=" .. random_rgb())
		end
	end
end

---Applies the created highlights to a specified buffer
---@param buffId integer
---@param merge_consecutive boolean
M.highlight_same_hash = function(buffId, merge_consecutive)
	M.nsId = vim.api.nvim_create_namespace("blame_ns")
	local lines = vim.api.nvim_buf_get_lines(buffId, 0, -1, false)

	for idx, line in ipairs(lines) do
		local hash = line:match("^%S+")
		local should_skip = false
		if idx > 1 and merge_consecutive then
			should_skip = lines[idx - 1]:match("^%S+") == hash
		end
		if hash == "00000000" or should_skip then
			vim.api.nvim_buf_add_highlight(buffId, M.nsId, "NotCommitedBlame", idx - 1, 0, -1)
		else
			vim.api.nvim_buf_add_highlight(buffId, M.nsId, "DimHashBlame", idx - 1, 0, 8)
			vim.api.nvim_buf_add_highlight(buffId, M.nsId, hash, idx - 1, 9, -1)
		end
	end
end

return M
