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
function Git:blame(filename, cwd, commit, callback, err_cb)
    local blame_command = {
        "git",
        "--no-pager",
        "blame",
        "--line-porcelain",
        commit or "@",
        filename,
    }
    local data
    local err_data
    vim.fn.jobstart(blame_command, {
        cwd = cwd,
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                return err_cb(table.concat(err_data, " "))
            end
            callback(data)
        end,
        on_stderr = function(_, d)
            err_data = d
        end,
        on_stdout = function(_, d)
            data = d
        end,
        stdout_buffered = true,
        stderr_buffered = true,
    })
end

function Git:git_root(cwd, callback, err_cb)
    local data
    local err_data
    vim.fn.jobstart({ "git", "rev-parse", "--show-toplevel" }, {
        cwd = cwd,
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                return err_cb(table.concat(err_data, " "))
            end
            callback(data)
        end,
        on_stderr = function(_, d)
            err_data = d
        end,
        on_stdout = function(_, d)
            data = d
        end,
        stdout_buffered = true,
        stderr_buffered = true,
    })
end

local function execute_command(command, cwd, callback, err_cb)
    local data
    local err_data
    vim.fn.jobstart(command, {
        cwd = cwd,
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                return err_cb(table.concat(err_data, " "))
            end
            callback(data)
        end,
        on_stderr = function(_, d)
            err_data = d
        end,
        on_stdout = function(_, d)
            data = d
        end,
        stdout_buffered = true,
        stderr_buffered = true,
    })
end

---Execute git show
---@param file_path string|nil relative file path
---@param cwd any cwd where to execute the command
---@param commit string
---@param callback fun(data: string[]) callback on exiting the command with output string
function Git:show(file_path, cwd, commit, callback, err_cb)
    local show_command = { "git", "--no-pager", "show" }

    if file_path then
        -- show_command = show_command .. ":" .. file_path
        table.insert(show_command, commit .. ":" .. file_path)
        execute_command(show_command, cwd, callback, err_cb)
    else
        table.insert(show_command, commit)
        execute_command(show_command, cwd, callback, err_cb)
    end
end

return Git
