local M = {}

---Parses raw porcelain data (string[]) into an array of tables for each line containing the commit data
---@param blame_porcelain string[]
---@return table[]
M.parse_porcelain = function(blame_porcelain)
	local all_lines = { {} }
	local next_is_content = false

	for _, entry in ipairs(blame_porcelain) do
		if entry == "" then
			break
		end
		if next_is_content then
			table.insert(all_lines, {})
			next_is_content = false
			goto continue
		end
		local ident = entry:match("%S+")
		if ident == "filename" then
			all_lines[#all_lines]["filename"] = string.sub(entry, 10, -1)
			next_is_content = true
		else
			if string.len(ident) == 40 then
				all_lines[#all_lines]["hash"] = ident
			else
				all_lines[#all_lines][ident] = string.sub(entry, string.len(ident) + 2, -1)
			end
		end
		::continue::
	end
	table.remove(all_lines)
	return all_lines
end

---Formats the lines with commit data into strings eg. (hash date author)
---@param blame_lines table[]
---@param config Config
---@return table
M.format_blame_to_line_string = function(blame_lines, config)
	local final_lines = {}
	for _, value in ipairs(blame_lines) do
		if next(value) == nil then
			goto continue
		end
		local formattedString = string.format(
			"%-8s %-10s %s",
			string.sub(value["hash"], 0, 8),
			os.date(config.date_format, value["committer-time"]),
			value["author"]
		)
		table.insert(final_lines, formattedString)
		::continue::
	end
	return final_lines
end

return M
