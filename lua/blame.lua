local virtual_blame = require("blame.virtual_blame")
local window_blame = require("blame.window_blame")
local blame_parser = require("blame.blame_parser")
local highlights = require("blame.highlights")

---@class Config
---@field date_format string Format of the output date
---@field width number|nil Manual setup of window width
local config = {
	date_format = "%Y/%m/%d %H:%M",
	width = nil,
}

---@class Blame
---@field config Config
---@field blame_lines table[]
local M = {}

---@type Config
M.config = config
---@type string[]
M.blame_lines = {}

---@param args Config?
M.setup = function(args)
	M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

---Creates a done hook for the 'git blame' command depending on the blame_type to show
---@param blame_type "window"|"virtual"|""
---@return function
local function done(blame_type)
	return function(_, exit_code)
		if exit_code ~= 0 then
			vim.notify("Could not execute blame, might not be a git repository", vim.log.levels.INFO)
			return
		end
		local parsed_blames = blame_parser.parse_porcelain(M.blame_lines)
		highlights.map_highlights_per_hash(parsed_blames)

		local line_strings = blame_parser.format_blame_to_line_string(parsed_blames, M.config)
		if blame_type == "window" or blame_type == "" then
			window_blame.window_blame(line_strings, M.config)
		elseif blame_type == "virtual" then
			virtual_blame.virtual_blame(parsed_blames, M.config)
		end
	end
end

---Captures the raw porcelain formatted data returned frim git blame
---@param _ any
---@param data string[]
local function stdout(_, data)
	M.blame_lines = data
end

---@param blame_type "window"|"virtual"|""
local function toggle(blame_type)
	local is_window_open = window_blame.is_window_open()
	local is_virtual_open = virtual_blame.nsId ~= nil

	if is_window_open or is_virtual_open then
		if is_window_open then
			window_blame.close_window()
		end
		if is_virtual_open then
			virtual_blame.close_virtual()
		end
		return
	end
	local blame_command = "git --no-pager blame --line-porcelain " .. vim.api.nvim_buf_get_name(0)
	vim.fn.jobstart(blame_command, {
		cwd = vim.fn.getcwd(),
		on_exit = done(blame_type),
		on_stdout = stdout,
		stdout_buffered = true,
		--on_stderr = error,
	})
end

M.toggle = function(blame_type)
	return toggle(blame_type["args"])
end

return M
