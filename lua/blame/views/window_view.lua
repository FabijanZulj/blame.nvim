local highlights = require("blame.highlights")
local BlameStack = require("blame.blame_stack")
local git = require("blame.git")
local CommitInfo = require("blame.commit_info")
local utils = require("blame.utils")
local mappings = require("blame.mappings")

---@class WindowView : BlameView
---@field config Config
---@field blame_window? integer
---@field original_window? integer
---@field git_client Git
---@field original_options any
---@field commit_info CommitInfo
---@field blame_stack_client BlameStack
local WindowView = {}

local blame_enabled_options = {
    cursorbind = true,
    scrollbind = true,
    cursorline = true,
    wrap = false,
}

---@return WindowView
function WindowView:new(config)
    local o = {}
    setmetatable(o, { __index = self })
    o.config = config
    o.blame_window = nil
    o.original_window = nil
    o.original_options = {}
    o.git_client = git:new(config)
    o.blamed_lines = nil
    o.commit_info = CommitInfo:new(config)
    o.blame_stack_client = nil
    return o
end

local function scroll_to_same_position(win_source, win_target)
    local win_line_source = vim.fn.line("w0", win_source)
    if
        not pcall(
            vim.api.nvim_win_set_cursor,
            win_target,
            { win_line_source + vim.wo[win_source].scrolloff, 0 }
        )
    then
        vim.api.nvim_win_set_cursor(win_target, { win_line_source, 0 })
    end

    vim.api.nvim_win_call(win_target, function()
        vim.cmd.normal({ "zt", bang = true })
    end)
end

---@param lines_with_hl LineWithHl[]
function WindowView:lines_with_hl_to_text_lines(lines_with_hl)
    local text_lines = {}
    for _, line in ipairs(lines_with_hl) do
        local text_fragments = {}
        for _, value in ipairs(line.values) do
            table.insert(text_fragments, value.textValue)
        end
        table.insert(
            text_lines,
            string.format(line.format, (table.unpack or unpack)(text_fragments))
        )
    end
    return text_lines
end

---@param lines_with_hl LineWithHl[]
function WindowView:add_highlights(lines_with_hl)
    local blame_buf = vim.api.nvim_win_get_buf(self.blame_window)
    local lines = vim.api.nvim_buf_get_lines(blame_buf, 0, -1, false)
    for _, line in ipairs(lines_with_hl) do
        for _, value in ipairs(line.values) do
            if value.hl then
                local text_line = lines[line.idx]
                local startindex, endindex =
                    string.find(text_line, value.textValue)
                if startindex ~= nil and endindex ~= nil then
                    vim.api.nvim_buf_add_highlight(
                        vim.api.nvim_win_get_buf(self.blame_window),
                        self.config.ns_id,
                        value.hl,
                        line.idx - 1,
                        startindex - 1,
                        endindex
                    )
                end
            end
        end
    end
end

---@param lines Porcelain[]
function WindowView:open(lines)
    self.blamed_lines = lines
    local lines_with_hl =
        highlights.get_hld_lines_from_porcelain(lines, self.config)
    local blame_lines = self:lines_with_hl_to_text_lines(lines_with_hl)

    highlights.create_highlights_per_hash(lines, self.config)

    -- blame window already opened, updating the content
    if self.blame_window ~= nil then
        return self:update_opened_blame_view(blame_lines, lines_with_hl)
    end

    local cursor_pos = vim.api.nvim_win_get_cursor(0)

    self.original_window = vim.api.nvim_get_current_win()

    vim.cmd("lefta vs")
    vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(false, true))
    self.blame_window = vim.api.nvim_get_current_win()
    vim.api.nvim_exec_autocmds(
        "User",
        { pattern = "BlameViewOpened", modeline = false, data = "window" }
    )

    local width = utils.longest_string_in_array(blame_lines) + 8
    vim.api.nvim_win_set_width(0, width)

    vim.api.nvim_buf_set_lines(0, 0, -1, false, blame_lines)

    self:add_highlights(lines_with_hl)

    vim.bo.bufhidden = "wipe"
    vim.bo.buftype = "nofile"
    vim.bo.swapfile = false
    vim.bo.modifiable = false
    vim.bo.ft = "blame"

    scroll_to_same_position(self.original_window, self.blame_window)
    self:setup_autocmd()
    self:setup_keybinds(vim.api.nvim_win_get_buf(self.blame_window))

    vim.api.nvim_win_set_cursor(self.blame_window, { cursor_pos[1], 0 })

    vim.wo[self.blame_window].spell = false
    vim.wo[self.blame_window].number = false
    vim.wo[self.blame_window].relativenumber = false
    vim.wo[self.blame_window].winbar = vim.wo[self.original_window].winbar
    vim.wo[self.blame_window].winfixwidth = true

    for option, value in pairs(blame_enabled_options) do
        self.original_options[option] = vim.api.nvim_get_option_value(
            option,
            { win = self.original_window }
        )
        vim.api.nvim_set_option_value(
            option,
            value,
            { win = self.original_window }
        )
        vim.api.nvim_set_option_value(
            option,
            value,
            { win = self.blame_window }
        )
    end
    vim.api.nvim_set_current_win(self.original_window)

    local file_path = vim.api.nvim_buf_get_name(
        vim.api.nvim_win_get_buf(self.original_window)
    )
    local cwd = vim.fn.expand("%:p:h")
    self.cwd = cwd
    self.blame_stack_client =
        BlameStack:new(self.config, self, self.original_window, file_path, cwd)
end

function WindowView:update_opened_blame_view(blame_lines, lines_with_hl)
    local width = utils.longest_string_in_array(blame_lines) + 8
    vim.api.nvim_win_set_width(self.blame_window, width)
    vim.bo[vim.api.nvim_win_get_buf(self.blame_window)].modifiable = true

    vim.api.nvim_buf_set_lines(
        vim.api.nvim_win_get_buf(self.blame_window),
        0,
        -1,
        false,
        blame_lines
    )

    self:add_highlights(lines_with_hl)

    vim.bo[vim.api.nvim_win_get_buf(self.blame_window)].modifiable = false

    -- Have to disable all options while syncing scroll on update
    for option, value in pairs(blame_enabled_options) do
        vim.api.nvim_set_option_value(
            option,
            not value,
            { win = self.blame_window }
        )

        vim.api.nvim_set_option_value(
            option,
            not value,
            { win = self.original_window }
        )
    end

    scroll_to_same_position(self.original_window, self.blame_window)

    -- and re-enable them here
    for option, value in pairs(blame_enabled_options) do
        vim.api.nvim_set_option_value(
            option,
            value,
            { win = self.blame_window }
        )

        vim.api.nvim_set_option_value(
            option,
            value,
            { win = self.original_window }
        )
    end
end

function WindowView:close(cleanup)
    if self.blame_window ~= nil then
        vim.api.nvim_del_augroup_by_name("NvimBlame")
        self.blame_stack_client:close()

        --if original window still present *Reset options*
        if vim.api.nvim_win_is_valid(self.original_window) then
            for option, _ in pairs(blame_enabled_options) do
                vim.api.nvim_set_option_value(
                    option,
                    self.original_options[option],
                    { win = self.original_window }
                )
            end
        end
        if not cleanup then
            vim.api.nvim_win_close(self.blame_window, true)
        end

        vim.api.nvim_exec_autocmds(
            "User",
            { pattern = "BlameViewClosed", modeline = false, data = "window" }
        )
        self.original_window = nil
        self.blame_window = nil
        self.blamed_lines = nil
    end
end

function WindowView:is_open()
    return self.blame_window ~= nil
end

function WindowView:setup_keybinds(buff)
    mappings.set_keymap(
        "n",
        "close",
        ":q<cr>",
        { buffer = buff, nowait = true, silent = true, noremap = true },
        self.config
    )

    mappings.set_keymap(
        "n",
        "show_commit",
        function()
            self:show_full_commit()
        end,
        { buffer = buff, nowait = true, silent = true, noremap = true },
        self.config
    )

    mappings.set_keymap(
        "n",
        "stack_push",
        function()
            self:blame_stack_push()
        end,
        { buffer = buff, nowait = true, silent = true, noremap = true },
        self.config
    )

    mappings.set_keymap(
        "n",
        "stack_push",
        function()
            self:blame_stack_push()
        end,
        { buffer = buff, nowait = true, silent = true, noremap = true },
        self.config
    )

    mappings.set_keymap(
        "n",
        "stack_pop",
        function()
            self:blame_stack_pop()
        end,
        { buffer = buff, nowait = true, silent = true, noremap = true },
        self.config
    )

    mappings.set_keymap(
        "n",
        "commit_info",
        function()
            self:open_commit_info()
        end,
        { buffer = buff, nowait = true, silent = true, noremap = true },
        self.config
    )
end

---Setup the commit buffer
---@param gshow_output any stdout output of git show
---@param hash string commit hash
local function setup_commit_buffer(gshow_output, hash, original_window)
    local gshow_buff = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_set_current_win(original_window)
    vim.api.nvim_buf_set_lines(gshow_buff, 0, -1, false, gshow_output)
    vim.api.nvim_buf_set_option(gshow_buff, "filetype", "git")
    vim.api.nvim_buf_set_option(gshow_buff, "buftype", "nofile")
    vim.api.nvim_buf_set_option(gshow_buff, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(gshow_buff, "readonly", true)
    vim.api.nvim_buf_set_name(gshow_buff, hash)

    return gshow_buff
end

function WindowView:open_commit_info()
    local row, _ = unpack(vim.api.nvim_win_get_cursor(self.blame_window))
    local commit = self.blamed_lines[row]
    self.commit_info:open(commit)
end

function WindowView:show_full_commit()
    local row, _ = unpack(vim.api.nvim_win_get_cursor(self.blame_window))
    local commit = self.blamed_lines[row]
    local view = self.config.commit_detail_view or "tab"

    local err_cb = function(err)
        vim.notify(err, vim.log.levels.INFO)
    end

    self.git_client:show(
        nil,
        self.cwd,
        commit.hash,
        function(show_output)
            vim.schedule(function()
                local gshow_buff = setup_commit_buffer(
                    show_output,
                    commit.hash,
                    self.original_window
                )

                if view == "tab" then
                    vim.cmd("tabnew")
                elseif view == "vsplit" then
                    vim.cmd("vsplit")
                elseif view == "split" then
                    vim.cmd("split")
                end

                if view == "current" then
                    vim.api.nvim_win_set_buf(self.original_window, gshow_buff)
                    self:close()
                else
                    mappings.set_keymap("n", "close", ":q<CR>", {
                        buffer = gshow_buff,
                        nowait = true,
                        silent = true,
                        noremap = true,
                    }, self.config)
                    self:close()
                    vim.api.nvim_win_set_buf(
                        vim.api.nvim_get_current_win(),
                        gshow_buff
                    )
                end
            end)
        end, err_cb
    )
end

function WindowView:blame_stack_push()
    local row, _ = unpack(vim.api.nvim_win_get_cursor(self.blame_window))
    local commit = self.blamed_lines[row]

    self.blame_stack_client:push(commit)
end

function WindowView:blame_stack_pop()
    self.blame_stack_client:pop()
end

---Sets the autocommands for the blame buffer
---@private
function WindowView:setup_autocmd()
    vim.api.nvim_create_autocmd({ "BufHidden", "BufUnload" }, {
        callback = function()
            vim.schedule(function()
                self.commit_info:close(false)
                self:close(true)
            end)
        end,
        buffer = vim.api.nvim_win_get_buf(self.blame_window),
        group = vim.api.nvim_create_augroup("NvimBlame", { clear = true }),
        desc = "Reset state to closed when the buffer is exited.",
    })

    vim.api.nvim_create_autocmd({ "CursorMoved" }, {
        callback = function()
            if self.commit_info:is_open() == true then
                self.commit_info:close(false)
            end
        end,
        buffer = vim.api.nvim_win_get_buf(self.blame_window),
        group = vim.api.nvim_create_augroup("NvimBlame", { clear = false }),
        desc = "Remove info window on cursor move",
    })
end

return WindowView
