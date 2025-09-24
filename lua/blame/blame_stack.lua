local git = require("blame.git")
local utils = require("blame.utils")
local porcelain_parser = require("blame.porcelain_parser")
local mappings = require("blame.mappings")

---@class BlameStack
---@field config Config
---@field blame_view WindowView
---@field git_client Git
---@field stack_buffer integer
---@field stack_info_float_win integer
---@field blame_window integer
---@field original_window integer
---@field original_buffer integer
---@field git_root string
---@field file_path string
---@field cwd string
---@field commit_stack Porcelain[]
---@field cursor_stack unknown[]
---@field original_cursor unknown
local BlameStack = {}

---@return BlameStack
function BlameStack:new(config, blame_view, file_path, cwd)
    local o = {}
    setmetatable(o, { __index = self })

    o.config = config
    o.blame_view = blame_view
    o.blame_window = blame_view.blame_window
    o.original_window = blame_view.original_window
    o.original_buffer = vim.api.nvim_win_get_buf(o.original_window)
    o.file_path = file_path
    o.cwd = cwd
    o.stack_buffer = nil
    o.git_client = git:new(config)
    o.git_client:git_root(cwd, function(git_root)
        self.git_root = git_root[1] .. "/"
    end, function()
        self.git_root = cwd
        vim.notify(
            "Could not get git root, some features might not work",
            vim.log.levels.WARN
        )
    end)

    o.commit_stack = {}
    o.cursor_stack = {}

    return o
end

function BlameStack:push(commit)
    if
        #self.commit_stack > 0
        and self.commit_stack[#self.commit_stack].hash == commit.hash
    then
        return
    end

    self:get_prev_file_content(commit, function(file_content, line)
        self:get_blame_for_commit(commit, true, function(blame_lines)
            if self.stack_buffer == nil then
                self:create_blame_buf()
            end

            vim.api.nvim_set_current_win(self.original_window)
            vim.api.nvim_set_current_buf(self.stack_buffer)

            vim.api.nvim_buf_set_lines(
                self.stack_buffer,
                0,
                -1,
                false,
                file_content
            )
            table.insert(self.commit_stack, commit)
            table.insert(self.cursor_stack, vim.api.nvim_win_get_cursor(self.blame_window))
            if #self.cursor_stack == 1 then
                self.original_cursor = self.cursor_stack[1]
            end
            self:open_stack_info_float()

            self.blame_view:open(blame_lines)
            if line ~= nil then
                vim.api.nvim_win_set_cursor(self.blame_window, { line, 0 })
            end
        end)
    end, function()
        vim.notify(
            "Cannot go to previous commit, might be the initial commit for the file",
            vim.log.levels.INFO
        )
    end)
end

function BlameStack:pop()
    if #self.commit_stack == 0 then
        return
    end
    if #self.commit_stack == 1 then
        self:reset_to_original_buf()
        return
    end
    table.remove(self.commit_stack, nil)
    local cursor = table.remove(self.cursor_stack, nil)
    self:open_stack_info_float()
    self:get_prev_file_content(
        self.commit_stack[#self.commit_stack],
        function(file_content, line)
            vim.api.nvim_buf_set_lines(
                self.stack_buffer,
                0,
                -1,
                false,
                file_content
            )
            vim.api.nvim_set_current_win(self.original_window)
            self:get_blame_for_commit(
                self.commit_stack[#self.commit_stack],
                true,
                function(blame_lines)
                    vim.schedule(function()
                        self.blame_view:open(blame_lines)
                        vim.api.nvim_win_set_cursor(self.blame_window, cursor)
                    end)
                end
            )
        end
    )
end

function BlameStack:create_blame_buf()
    self.stack_buffer = vim.api.nvim_create_buf(true, true)
    vim.bo[self.stack_buffer].ft = vim.bo[self.original_buffer].ft
    mappings.set_keymap("n", "stack_pop", function()
        self:pop()
    end, {
        buffer = self.stack_buffer,
        nowait = true,
        silent = true,
        noremap = true,
    }, self.config)

    mappings.set_keymap("n", "stack_push", function()
        local row, _ = unpack(vim.api.nvim_win_get_cursor(self.original_window))
        local c = self.blame_view.blamed_lines[row]
        self:push(c)
    end, {
        buffer = self.stack_buffer,
        nowait = true,
        silent = true,
        noremap = true,
    }, self.config)

    vim.api.nvim_buf_set_name(self.stack_buffer, "Blame stack")

    vim.api.nvim_create_autocmd({ "BufHidden", "BufUnload" }, {
        callback = function()
            vim.schedule(function()
                self:reset_to_original_buf()
                self:close()
                if self.config.focus_blame then
                    vim.api.nvim_set_current_win(self.blame_window)
                end
            end)
        end,
        buffer = self.stack_buffer,
        group = vim.api.nvim_create_augroup("NvimBlame", { clear = false }),
        desc = "Reset state when closing blame buffer",
    })
end

function BlameStack:reset_to_original_buf()
    self.commit_stack = {}
    self.cursor_stack = {}
    vim.api.nvim_set_current_win(self.original_window)
    vim.api.nvim_set_current_buf(self.original_buffer)
    if self.stack_buffer and vim.api.nvim_buf_is_valid(self.stack_buffer) then
        vim.api.nvim_buf_delete(self.stack_buffer, { force = true })
    end
    ---@diagnostic disable-next-line: missing-fields
    self:get_blame_for_commit({}, false, function(blame_lines)
        vim.schedule(function()
            self.blame_view:open(blame_lines)
            if self.original_cursor ~= nil then
                vim.api.nvim_win_set_cursor(self.blame_window, self.original_cursor)
            end
        end)
    end)
    self.stack_buffer = nil
    self:close_stack_info_float()
end

function BlameStack:open_stack_info_float()
    if self.stack_info_float_win ~= nil then
        local info_buf = vim.api.nvim_win_get_buf(self.stack_info_float_win)
        local lines_text = {}
        for _, v in pairs(self.commit_stack) do
            table.insert(
                lines_text,
                string.sub(v.hash, 0, 7)
                    .. " "
                    .. v.author
                    .. " "
                    .. utils.format_time(self.config.date_format, v.committer_time)
            )
        end
        vim.api.nvim_buf_set_lines(info_buf, 0, -1, false, lines_text)

        local lns = vim.api.nvim_buf_get_lines(info_buf, 0, -1, false)
        for idx, v in ipairs(lns) do
            vim.api.nvim_buf_set_extmark(info_buf, -1, idx - 1, 0, {
                end_col = -1,
                hl_group = idx == #lns and string.sub(v, 0, 7) or "Comment",
            })
        end

        local width = utils.longest_string_in_array(lines_text) + 5
        local height = #self.commit_stack
        vim.api.nvim_win_set_height(self.stack_info_float_win, height)
        vim.api.nvim_win_set_width(self.stack_info_float_win, width)
        vim.api.nvim_win_set_cursor(self.stack_info_float_win, { height, 0 })
        return
    end

    local info_buf = vim.api.nvim_create_buf(false, true)
    local lines_text = {}
    for _, v in pairs(self.commit_stack) do
        table.insert(
            lines_text,
            string.sub(v.hash, 0, 7)
                .. " "
                .. v.author
                .. " "
                .. utils.format_time(self.config.date_format, v.committer_time)
        )
    end
    vim.api.nvim_buf_set_lines(info_buf, 0, -1, false, lines_text)

    vim.api.nvim_buf_set_extmark(info_buf, -1, 0, 0, {
        end_col = -1,
        hl_group = string.sub(lines_text[1], 0, 7),
    })

    local width = utils.longest_string_in_array(lines_text) + 5
    local height = #self.commit_stack

    self.stack_info_float_win = vim.api.nvim_open_win(info_buf, false, {
        relative = "win",
        col = vim.api.nvim_win_get_width(self.original_window),
        win = self.original_window,
        row = 1,
        width = width,
        height = height,
        border = "rounded",
    })
    vim.wo[self.stack_info_float_win].number = false
    vim.wo[self.stack_info_float_win].relativenumber = false
    vim.wo[self.stack_info_float_win].signcolumn = "no"
    vim.wo[self.stack_info_float_win].scrollbind = false
    vim.wo[self.stack_info_float_win].cursorbind = false

    vim.api.nvim_win_set_height(self.stack_info_float_win, height)
    vim.api.nvim_win_set_cursor(self.stack_info_float_win, { height, 0 })
end

function BlameStack:close_stack_info_float()
    if
        self.stack_info_float_win
        and vim.api.nvim_win_is_valid(self.stack_info_float_win)
    then
        vim.api.nvim_win_close(self.stack_info_float_win, true)
    end
    self.stack_info_float_win = nil
end

function BlameStack:close()
    self:close_stack_info_float()
    if vim.api.nvim_win_is_valid(self.original_window) then
        vim.api.nvim_win_set_buf(self.original_window, self.original_buffer)
    end
    if
        self.stack_buffer ~= nil
        and vim.api.nvim_buf_is_valid(self.stack_buffer)
    then
        vim.api.nvim_buf_delete(self.stack_buffer, { force = true })
    end
    self.stack_buffer = nil
    self.commit_stack = {}
end

---Get hash and filepath for (previous) commit
---@param commit Porcelain
---@param prev boolean should show previous commit
---@return string hash, string filepath
function BlameStack:get_hash_and_filepath(commit, prev)
    local hash, filepath
    if prev then
        if commit.previous then
            hash, filepath = commit.previous:match("(.-) (.+)")
        else
            hash = commit.hash .. "^"
        end
    else
        hash = commit.hash
    end
    return hash, filepath or commit.filename or self.file_path
end

---@param commit Porcelain
---@param prev boolean should show previous commit
---@param cb fun(any) callback on blame command end
---@param err_cb nil | fun(err) callback on error blame command
function BlameStack:get_blame_for_commit(commit, prev, cb, err_cb)
    local hash, filepath = self:get_hash_and_filepath(commit, prev)
    self.git_client:blame(filepath, self.git_root, hash, function(data)
        vim.schedule(function()
            local parsed_blames = porcelain_parser.parse_porcelain(data)
            if cb ~= nil then
                cb(parsed_blames)
            end
        end)
    end, function(err)
        if err_cb then
            err_cb(err)
        else
            vim.notify(err, vim.log.levels.INFO)
        end
    end)
end

---@param commit Porcelain
---@param cb fun(any, number?) callback on show command end
---@param err_cb nil | fun(err) callback on error show command
function BlameStack:get_prev_file_content(commit, cb, err_cb)
    local hash, filepath = self:get_hash_and_filepath(commit, true)
    self.git_client:show(filepath, self.git_root, hash, function(file_content)
        self.git_client:diff(filepath, self.git_root, hash, commit.hash, function(diff)
            -- most of the time empty line is inserted from git-show. Might create issues but for now this crude check works
            if file_content[#file_content] == "" then
                table.remove(file_content)
            end

            local line
            for _, hunk in ipairs(porcelain_parser.parse_hunks(diff)) do
                if hunk.curr_line <= commit.original_line and commit.original_line < hunk.curr_line + hunk.curr_count then
                    line = hunk.prev_line
                    break
                end
            end

            vim.schedule(function()
                if cb ~= nil then
                    cb(file_content, line)
                end
            end)
        end, function(err)
            if err_cb then
                err_cb(err)
            else
                vim.notify(err, vim.log.levels.INFO)
            end
        end)
    end, function(err)
        if err_cb then
            err_cb(err)
        else
            vim.notify(err, vim.log.levels.INFO)
        end
    end)
end

return BlameStack
