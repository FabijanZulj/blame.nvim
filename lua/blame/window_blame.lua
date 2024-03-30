local util = require("blame.util")
local highlights = require("blame.highlights")
local git = require("blame.git")

local M = {}
M.blame_window = nil
M.blame_buffer = nil
M.original_window = nil
M.gshow_output = nil

M.blame_enabled_options = { "cursorbind", "scrollbind", "cursorline" }
M.original_options = {}

---Sets the autocommands for the blame buffer
local function setup_autocmd(blame_buff)
	vim.api.nvim_create_autocmd({ "BufHidden", "BufUnload" }, {
		callback = function()
			if M.blame_buffer ~= nil then
				M.reset_to_closed_state()
			end
		end,
		buffer = blame_buff,
		group = "BlameNvim",
		desc = "Reset state to closed when the buffer is exited.",
	})
end

---Sets the keybinds for the blame buffer
local function setup_keybinds(buff, config)
	vim.keymap.set("n", "q", ":q<cr>", { buffer = buff, nowait = true, silent = true, noremap = true })
	vim.keymap.set("n", "<esc>", ":q<cr>", { buffer = buff, nowait = true, silent = true, noremap = true })
	vim.keymap.set(
		"n",
		"<cr>",
        function()
            M.show_full_commit(config)
        end,
		{ buffer = buff, nowait = true, silent = true, noremap = true }
	)
end

---Open window blame
---@param blame_lines any[]
---@param config Config
M.window_blame = function(blame_lines, config)
	local width = config["width"] or (util.longest_string_in_array(blame_lines) + 8)
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	M.original_window = vim.api.nvim_get_current_win()

	vim.cmd("lefta vs")
	M.blame_window = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_width(M.blame_window, width)
	M.blame_buffer = vim.api.nvim_create_buf(false, true)

	vim.api.nvim_win_set_buf(M.blame_window, M.blame_buffer)
	vim.api.nvim_buf_set_lines(M.blame_buffer, 0, -1, false, blame_lines)
	vim.api.nvim_buf_set_option(M.blame_buffer, "filetype", "blame")

	util.scroll_to_same_position(M.original_window, M.blame_window)

	setup_keybinds(M.blame_buffer, config)
	setup_autocmd(M.blame_buffer)

	vim.api.nvim_win_set_cursor(M.blame_window, cursor_pos)

    for _, option in ipairs(M.blame_enabled_options) do
        M.original_options[option] = vim.api.nvim_get_option_value("cursorline", { win = M.original_window })
        vim.api.nvim_set_option_value(option, true, { win = M.original_window })
	    vim.api.nvim_set_option_value(option, true, { win = M.blame_window })
    end

	vim.api.nvim_set_current_win(M.original_window)
	highlights.highlight_same_hash(M.blame_buffer, config.merge_consecutive)
	vim.api.nvim_set_option_value("modifiable", false, { buf = M.blame_buffer, })
	vim.api.nvim_set_option_value("spell", false, { win = M.blame_window })
	vim.api.nvim_set_option_value("number", false, { win = M.blame_window })
	vim.api.nvim_set_option_value("relativenumber", false, { win = M.blame_window })
end

---Setup the commit buffer
---@param gshow_output any stdout output of git show
---@param hash string commit hash
local function setup_commit_buffer(gshow_output, hash)
    local gshow_buff = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_set_current_win(M.original_window)
    vim.api.nvim_buf_set_lines(gshow_buff, 0, -1, false, gshow_output)
    vim.api.nvim_buf_set_option(gshow_buff, "filetype", "git")
    vim.api.nvim_buf_set_option(gshow_buff, "buftype", "nofile")
    vim.api.nvim_buf_set_option(gshow_buff, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(gshow_buff, "readonly", true)
    vim.api.nvim_buf_set_name(gshow_buff, hash)



    return gshow_buff
end

---Git show command done callback
---@param _ any
---@param status any exit status of command
---@param config Config
local function show_done(_, status, config)
    if status == 0 and M.gshow_output ~= nil then
        local hash = M.gshow_output[1]:match("commit (%S+)")
        local view = config.commit_detail_view or "tab"
        local gshow_buff = setup_commit_buffer(M.gshow_output, hash)

        if view == "tab" then
            vim.cmd("tabnew")
        elseif view == "vsplit" then
            vim.cmd("vsplit")
        elseif view == "split" then
            vim.cmd("split")
        end

        -- here for backward compatibility
        if view == "current" then
            vim.api.nvim_win_set_buf(M.original_window, gshow_buff)
            M.close_window()
        else
            vim.api.nvim_buf_set_keymap(
                gshow_buff, "n", "q", ":q<CR>",
                { nowait = true, silent = true, noremap = true }
            )
            M.close_window()
            vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), gshow_buff)
        end
    else
        vim.notify("Could not open full commit info", vim.log.levels.INFO)
    end
end



---Output of git show
---@param _ any
---@param gshow_output any stdout output of git show
local function show_output(_, gshow_output)
	M.gshow_output = gshow_output
end

---Get git show output for hash under cursor
M.show_full_commit = function(config)
    local row, _ = unpack(vim.api.nvim_win_get_cursor(M.blame_window))
    local blame_line = vim.api.nvim_buf_get_lines(M.blame_buffer, row - 1, row, false)[1]
    local hash = blame_line:match("^%S+")
    git.show(hash, vim.fn.getcwd(),
        function(_, status)
            show_done(_, status, config)
        end,
        show_output
    )
end

---Close the blame window
M.close_window = function()

    for option, value in pairs(M.original_options) do
        vim.api.nvim_set_option_value(option, value, { win = M.original_window })
    end

	local buff = M.blame_buffer
	vim.api.nvim_win_close(M.blame_window, true)
	vim.api.nvim_buf_delete(buff, { force = true })
end

---Reset the state to initial/closed state
M.reset_to_closed_state = function()
	vim.api.nvim_set_option_value("cursorbind", false, { win = M.original_window })
	vim.api.nvim_set_option_value("scrollbind", false, { win = M.original_window })
	M.original_window = nil
	M.blame_window = nil
	M.blame_buffer = nil
end

M.is_window_open = function()
	return M.blame_window ~= nil and vim.api.nvim_win_is_valid(M.blame_window)
end

return M
