local util = require("blame.util")
local M = {}

M.original_buffer = nil
M.nsId = nil

---Creates the virtual text floated to theright with the blame lines
---@param blame_lines string[]
---@param config Config
M.virtual_blame = function(blame_lines, config)
	M.original_buffer = vim.api.nvim_win_get_buf(0)
	M.nsId = vim.api.nvim_create_namespace("blame")

	local lines
	if config.virtual_style == "float" then
		lines = M.create_lines_with_padding(blame_lines, config)
	else
		lines = M.create_lines(blame_lines, config)
	end

	for _, line in pairs(lines) do
		vim.api.nvim_buf_set_extmark(M.original_buffer, M.nsId, line["idx"], 0, {
			virt_text_pos = "right_align",
			virt_text = {
				{ line["author"]["value"], line["author"]["hl"] },
				{ line["date"]["value"], line["date"]["hl"] },
				{ line["hash"]["value"], line["hash"]["hl"] },
			},
		})
	end
end

M.create_lines = function(blame_lines, config)
	local lines = {}
	for i, value in ipairs(blame_lines) do
		local hash = string.sub(value["hash"], 0, 8)
		local is_not_commited = hash == "00000000"
		if not is_not_commited then
			table.insert(lines, {
				idx = i,
				author = {
					value = value["author"] .. "  ",
					hl = hash,
				},
				date = {
					value = os.date(config.date_format .. "  ", value["committer-time"]),
					hl = hash,
				},
				hash = {
					value = hash,
					hl = "DimHashBlame",
				},
			})
		end
	end
	return lines
end

M.create_lines_with_padding = function(blame_lines, config)
	local mapped_lines = {}
	local lines = vim.api.nvim_buf_get_lines(M.original_buffer, 0, -1, false)
	local longest_line = util.longest_string_in_array(lines)

	for i, value in ipairs(blame_lines) do
		local hash = string.sub(value["hash"], 0, 8)
		local is_not_commited = hash == "00000000"

		local author = value["author"] .. " "
		local date = os.date(config.date_format .. "  ", value["committer-time"])
		local hash_content = hash

		local content_length = vim.fn.strdisplaywidth(author .. date .. hash_content)
		local window_width = vim.api.nvim_win_get_width(0)

		local padding_needed = window_width - longest_line - content_length - 8

		if not is_not_commited then
			table.insert(mapped_lines, {
				idx = i,
				author = {
					value = author,
					hl = hash,
				},
				date = {
					value = date,
					hl = hash,
				},
				hash = {
					value = hash_content .. string.rep(" ", padding_needed),
					hl = "DimHashBlame",
				},

				content = value["content"],
			})
		end
	end
	return mapped_lines
end

---Removes the virtual text
M.close_virtual = function()
	vim.api.nvim_buf_clear_namespace(M.original_buffer, M.nsId, 0, -1)
	M.nsId = nil
end

return M
