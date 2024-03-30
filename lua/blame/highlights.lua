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
---@param parsed table[]
---@param merge_consecutive boolean
---@param config Config
M.highlight_same_hash = function(buffId, parsed, merge_consecutive, config)
	M.nsId = vim.api.nvim_create_namespace("blame_ns")

	for idx, line in ipairs(parsed) do
		local hash = string.sub(line["hash"], 0, 8)
		local should_skip = false
		if idx > 1 and merge_consecutive then
			should_skip = parsed[idx - 1]["hash"] == hash
		end
		if hash == "00000000" or should_skip then
			vim.api.nvim_buf_add_highlight(buffId, M.nsId, "NotCommitedBlame", idx - 1, 0, -1)
		else
			local start = 0
			if config.format == nil then
				vim.api.nvim_buf_add_highlight(buffId, M.nsId, "DimHashBlame", idx - 1, 0, 8)
				start = 9
			end
			vim.api.nvim_buf_add_highlight(buffId, M.nsId, hash, idx - 1, start, -1)
		end
	end
end

return M
