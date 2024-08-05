local utils = require("blame.utils")
local mappings = require("blame.mappings")

---@class CommitInfo
---@field config Config
---@field commit_info_window integer | nil
local CommitInfo = {}

function CommitInfo:new(config)
    local o = {}
    o.config = config
    setmetatable(o, { __index = self })
    return o
end

function CommitInfo:is_open()
    return self.commit_info_window ~= nil
end

function CommitInfo:close(cleanup)
    if
        cleanup == false
        and self.commit_info_window
        and vim.api.nvim_win_is_valid(self.commit_info_window)
    then
        vim.api.nvim_win_close(self.commit_info_window, true)
    end
    self.commit_info_window = nil
end

---@param commit Porcelain
function CommitInfo:open(commit)
    if self.commit_info_window then
        vim.api.nvim_set_current_win(self.commit_info_window)
        return
    end
    local formatted_commit = {}
    for k, v in pairs(commit) do
        if type(v) == "string" and k ~= "content" then
            table.insert(formatted_commit, k .. ": " .. v)
        end
    end
    table.sort(formatted_commit)
    local info_buf = vim.api.nvim_create_buf(false, true)
    local width = utils.longest_string_in_array(formatted_commit) + 5
    local height = #formatted_commit
    self.commit_info_window = vim.api.nvim_open_win(info_buf, false, {
        relative = "cursor",
        col = 0,
        row = 1,
        width = width,
        height = height,
        border = "rounded",
    })

    vim.api.nvim_buf_set_lines(info_buf, 0, -1, false, formatted_commit)

    for idx, line in ipairs(formatted_commit) do
        local key_end = string.find(line, ":") - 1
        vim.api.nvim_buf_add_highlight(
            info_buf,
            self.config.ns_id,
            "Comment",
            idx - 1,
            0,
            key_end
        )
    end

    mappings.set_keymap(
        "n",
        "close",
        ":q<cr>",
        { buffer = info_buf, nowait = true, silent = true, noremap = true },
        self.config
    )

    vim.api.nvim_create_autocmd({ "BufHidden", "BufUnload" }, {
        callback = function()
            self:close(true)
        end,
        buffer = info_buf,
        group = vim.api.nvim_create_augroup("NvimBlame", { clear = false }),
        desc = "Clean up info window on buf close",
    })
end

return CommitInfo
