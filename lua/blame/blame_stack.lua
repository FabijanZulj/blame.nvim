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
---@field original_window integer
---@field initial_commit string
---@field original_buffer integer
---@field file_path string
---@field cwd string
---@field commit_stack Porcelain[]
local BlameStack = {}

---@return BlameStack
function BlameStack:new(config, blame_view, original_window, file_path, cwd)
    local o = {}
    setmetatable(o, { __index = self })

    o.config = config
    o.blame_view = blame_view
    o.original_window = original_window
    o.original_buffer = vim.api.nvim_win_get_buf(o.original_window)
    o.file_path = file_path
    o.cwd = cwd
    o.stack_buffer = nil
    o.git_client = git:new(config)
    o.git_client:initial_commit(o.file_path, o.cwd, function(initial_commit)
        self.initial_commit = initial_commit
    end)

    o.commit_stack = {}

    return o
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
    self:open_stack_info_float()
    self:show_file_content(
        self.commit_stack[#self.commit_stack],
        self.stack_buffer,
        true,
        function()
            vim.api.nvim_set_current_win(self.original_window)
            self:blame_for_commit(self.commit_stack[#self.commit_stack], true)
        end
    )
end

function BlameStack:reset_to_original_buf()
    self.commit_stack = {}
    vim.api.nvim_set_current_win(self.original_window)
    vim.api.nvim_set_current_buf(self.original_buffer)
    if self.stack_buffer and vim.api.nvim_buf_is_valid(self.stack_buffer) then
        vim.api.nvim_buf_delete(self.stack_buffer, { force = true })
    end
    self:blame_for_commit({ hash = nil })
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
                    .. os.date(self.config.date_format, v.committer_time)
            )
        end
        vim.api.nvim_buf_set_lines(info_buf, 0, -1, false, lines_text)

        local lns = vim.api.nvim_buf_get_lines(info_buf, 0, -1, false)
        for idx, v in ipairs(lns) do
            vim.api.nvim_buf_add_highlight(
                info_buf,
                -1,
                idx == #lns and string.sub(v, 0, 7) or "Comment",
                idx - 1,
                0,
                -1
            )
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
                .. os.date(self.config.date_format, v.committer_time)
        )
    end
    vim.api.nvim_buf_set_lines(info_buf, 0, -1, false, lines_text)

    vim.api.nvim_buf_add_highlight(
        info_buf,
        -1,
        string.sub(lines_text[1], 0, 7),
        0,
        0,
        -1
    )

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

function BlameStack:push(commit)
    if commit.hash == self.initial_commit then
        vim.notify(
            "There is nothing previous to this commit for this file",
            vim.log.levels.INFO
        )
        return
    end
    if
        #self.commit_stack > 0
        and self.commit_stack[#self.commit_stack].hash == commit.hash
    then
        return
    end
    if self.stack_buffer == nil then
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
            local row, _ =
                unpack(vim.api.nvim_win_get_cursor(self.original_window))
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
                end)
            end,
            buffer = self.stack_buffer,
            group = vim.api.nvim_create_augroup("NvimBlame", { clear = false }),
            desc = "Reset state when closing blame buffer",
        })
    end

    vim.api.nvim_set_current_win(self.original_window)
    vim.api.nvim_set_current_buf(self.stack_buffer)

    table.insert(self.commit_stack, commit)
    self:open_stack_info_float()

    self:show_file_content(commit, self.stack_buffer, true, function()
        self:blame_for_commit(commit, true)
    end)
end

function BlameStack:close()
    self:close_stack_info_float()
    vim.api.nvim_win_set_buf(self.original_window, self.original_buffer)
    if
        self.stack_buffer ~= nil
        and vim.api.nvim_buf_is_valid(self.stack_buffer)
    then
        vim.api.nvim_buf_delete(self.stack_buffer, { force = true })
    end
    self.stack_buffer = nil
    self.commit_stack = {}
end

function BlameStack:blame_for_commit(commit, prev, cb)
    self.git_client:blame(
        self.file_path,
        self.cwd,
        prev and commit.hash .. "^" or commit.hash,
        function(data)
            vim.schedule(function()
                local parsed_blames = porcelain_parser.parse_porcelain(data)
                self.blame_view:open(parsed_blames)
                if cb ~= nil then
                    cb()
                end
            end)
        end
    )
end

function BlameStack:show_file_content(commit, buf, prev, cb)
    self.git_client:show(
        self.file_path,
        self.cwd,
        prev and commit.hash .. "^" or commit.hash,
        function(file_content)
            vim.schedule(function()
                -- most of the time empty line is inserted from git-show. Might create issues but for now this crude check works
                if file_content[#file_content] == "" then
                    table.remove(file_content)
                end

                vim.api.nvim_buf_set_lines(buf, 0, -1, false, file_content)
                if cb ~= nil then
                    cb()
                end
            end)
        end
    )
end

return BlameStack
