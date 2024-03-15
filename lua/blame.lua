local virtual_blame = require("blame.virtual_blame")
local window_blame = require("blame.window_blame")
local blame_parser = require("blame.blame_parser")
local highlights = require("blame.highlights")
local git = require("blame.git")

---@class Config
---@field date_format string Format of the output date
---@field width number|nil Manual setup of window width
---@field virtual_style "float"|"right_align"
---@field merge_consecutive boolean Should same commits be ignored after first line
---@field commit_detail_view string "tab"|"split"|"vsplit"|"current" How to open commit details
local config = {
	date_format = "%Y/%m/%d %H:%M",
	width = nil,
	virtual_style = "right_align",
	merge_consecutive = false,
    commit_detail_view = "tab",
}

---@class Blame
---@field config Config
---@field blame_lines table[]
local M = {}

---@type Config
M.config = config
---@type string[]
M.blame_lines = {}
M.blame_nvim_augroup = vim.api.nvim_create_augroup("BlameNvim", { clear = false })

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

---Captures the raw porcelain formatted data returned from git blame
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
	git.blame(vim.api.nvim_buf_get_name(0), vim.fn.expand('%:p:h'), done(blame_type), stdout)
end

---@param blame_type "window"|"virtual"|""
local function enable(blame_type)
	local is_window_open = window_blame.is_window_open()
	local is_virtual_open = virtual_blame.nsId ~= nil

	if is_window_open or is_virtual_open then
		return
	else
		git.blame(vim.api.nvim_buf_get_name(0), vim.fn.expand('%:p:h'), done(blame_type), stdout)
	end
end

local function disable()
	local is_window_open = window_blame.is_window_open()
	local is_virtual_open = virtual_blame.nsId ~= nil

	if is_window_open then
		window_blame.close_window()
	elseif is_virtual_open then
		virtual_blame.close_virtual()
	end
end

M.toggle = function(arguments)
	return toggle(arguments["args"])
end

M.enable = function(arguments)
	return enable(arguments["args"])
end

M.disable = function()
	return disable()
end

return M
