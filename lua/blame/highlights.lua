local M = {}
M.nsId = nil

---@return string
local function random_rgb(custom_colors)
    if custom_colors and #custom_colors > 0 then
        local index = math.random(1, #custom_colors)
        return custom_colors[index]
    else
        local r = math.random(100, 255)
        local g = math.random(100, 255)
        local b = math.random(100, 255)
        return string.format("#%02X%02X%02X", r, g, b)
    end
end

M.setup_highlights = function()
	vim.api.nvim_set_hl(0, 'DimHashBlame', { fg = "DimGray", default = true })
	vim.api.nvim_set_hl(0, 'NotCommitedBlame', { fg = "NONE", bg = "NONE", default = true })
	vim.api.nvim_set_hl(0, 'SkipedBlame', { fg = "NONE", bg = "NONE", default = true })
end

---Creates the highlights for Hash, NotCommited and random color per one hash
---@param parsed_lines any
---@param config Config
M.map_highlights_per_hash = function(parsed_lines, config)
	M.nsId = vim.api.nvim_create_namespace("blame_ns")
	for _, value in ipairs(parsed_lines) do
		local full_hash = value["hash"]
		local hash = string.sub(full_hash, 0, 8)
		if next(vim.api.nvim_get_hl(M.nsId, { name = hash })) == nil then
			vim.api.nvim_set_hl(M.nsId, hash, { fg = random_rgb(config.colors), })
		end
	end
end

---Applies the created highlights to a specified buffer
---@param buffId integer
---@param winId integer
---@param parsed table[]
---@param merge_consecutive boolean
---@param config Config
M.highlight_same_hash = function(buffId, winId, parsed, merge_consecutive, config)
	vim.api.nvim_win_set_hl_ns(winId, M.nsId)
	for idx, line in ipairs(parsed) do
		local hash = string.sub(line["hash"], 0, 8)
		local should_skip = false
		if idx > 1 and merge_consecutive then
			should_skip = parsed[idx - 1]["hash"] == hash
		end
		if hash == "00000000" then
			vim.api.nvim_buf_add_highlight(buffId, M.nsId, "NotCommitedBlame", idx - 1, 0, -1)
		elseif should_skip then
			vim.api.nvim_buf_add_highlight(buffId, M.nsId, "SkipedBlame", idx - 1, 0, -1)
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
