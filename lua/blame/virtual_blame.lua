local M = {}

M.original_buffer = nil
M.nsId = nil

---Creates the virtual text floated to theright with the blame lines
---@param blame_lines string[]
---@param config Config
M.virtual_blame = function(blame_lines, config)
	M.original_buffer = vim.api.nvim_win_get_buf(0)
	M.nsId = vim.api.nvim_create_namespace("blame")

	for i, value in ipairs(blame_lines) do
		local hash = string.sub(value["hash"], 0, 8)
		local is_not_commited = hash == "00000000"
		if not is_not_commited then
			vim.api.nvim_buf_set_extmark(M.original_buffer, M.nsId, i - 1, 0, {
				virt_text_pos = "right_align",
				virt_text = {
					{ value["author"] .. "  ", hash },
					{
						os.date(config.date_format .. "  ", value["committer-time"]),
						hash,
					},
					{ hash, "DimHashBlame" },
				},
			})
		end
	end
end

---Removes the virtual text
M.close_virtual = function()
	vim.api.nvim_buf_clear_namespace(M.original_buffer, M.nsId, 0, -1)
	M.nsId = nil
end

return M
