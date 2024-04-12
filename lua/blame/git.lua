---@class Git
---@field config Config
local Git = {}

---@return Git
function Git:new(config)
    local o = {}
    setmetatable(o, { __index = self })

    o.config = config
    return o
end

---Execute git blame line porcelain command, returns output string
---@param filename string
---@param cwd any cwd where to execute the command
---@param commit string|nil
---@param callback fun(data: string[]) callback on exiting the command with output string
function Git:blame(filename, cwd, commit, callback)
    local blame_command = "git --no-pager blame --line-porcelain "
        .. (commit and commit or "")
        .. " -- "
        .. '"'
        .. filename
        .. '"'
    local data
    vim.fn.jobstart(blame_command, {
        cwd = cwd,
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                vim.notify(
                    "Could not execute blame, might not be a git repository",
                    vim.log.levels.INFO
                )
                return
            end
            callback(data)
        end,
        on_stdout = function(_, d)
            data = d
        end,
        stdout_buffered = true,
    })
end

---Execute git show
---@param file_path string|nil absolute file path
---@param cwd any cwd where to execute the command
---@param commit string
---@param callback fun(data: string[]) callback on exiting the command with output string
function Git:show(file_path, cwd, commit, callback)
    local show_command = "git --no-pager show " .. commit
    if file_path then
        local git_root = vim.fn.system("git rev-parse --show-toplevel") .. "/"
        local relative_file_path = string.sub(file_path, string.len(git_root))
        show_command = show_command .. ":" .. relative_file_path
    end
    local data
    vim.fn.jobstart(show_command, {
        cwd = cwd,
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                vim.notify(
                    "Could not execute show, might not be a git repository",
                    vim.log.levels.INFO
                )
                return
            end
            callback(data)
        end,
        on_stdout = function(_, d)
            data = d
        end,
        stdout_buffered = true,
    })
end

return Git
