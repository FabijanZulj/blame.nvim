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
                return callback({})
            end
            callback(data)
        end,
        on_stdout = function(_, d)
            data = d
        end,
        stdout_buffered = true,
    })
end

function Git:git_root(cwd, callback)
    local data
    vim.fn.jobstart("git rev-parse --show-toplevel", {
        cwd = cwd,
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                vim.notify("Could not find git root", vim.log.levels.INFO)
                return callback("")
            end
            callback(data)
        end,
        on_stdout = function(_, d)
            data = d
        end,
        stdout_buffered = true,
    })
end

local function execute_command(command, cwd, callback, default_value)
    local data
    vim.fn.jobstart(command, {
        cwd = cwd,
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                vim.notify("Could not execute git command", vim.log.levels.INFO)
                return callback(default_value)
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
        self:git_root(cwd, function(git_root_output)
            local git_root = git_root_output[1] .. "/"
            local relative_file_path =
                string.sub(file_path, string.len(git_root) + 1)
            show_command = show_command .. ":" .. relative_file_path
            execute_command(show_command, cwd, callback, {})
        end)
    else
        execute_command(show_command, cwd, callback, {})
    end
end

---Find initial commit hash for given file
---@param file_path string|nil absolute file path
---@param cwd any cwd where to execute the command
---@param callback fun(data: string) callback on exiting the command with output string
function Git:initial_commit(file_path, cwd, callback)
    local log_command = "git log --diff-filter=A " .. file_path

    local data
    vim.fn.jobstart(log_command, {
        cwd = cwd,
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                vim.notify("Could not execute `git show`", vim.log.levels.INFO)
                return callback("")
            end
            local commit = string.sub(data[1], 8)
            callback(commit)
        end,
        on_stdout = function(_, d)
            data = d
        end,
        stdout_buffered = true,
    })
end

return Git
