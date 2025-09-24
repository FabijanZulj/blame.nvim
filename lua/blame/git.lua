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

local function add_blame_options(blame_command, blame_options)
    if blame_options == nil then
        return
    end

    local index = #blame_command - 2
    for i = 1, #blame_options do
        table.insert(blame_command, index + i, blame_options[i])
    end
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
        filename,
    }
    add_blame_options(blame_command, self.config.blame_options)
    if commit ~= nil then
        table.insert(blame_command, #blame_command - 1, commit)
    end
    execute_command(blame_command, cwd, callback, err_cb)
end

function Git:git_root(cwd, callback, err_cb)
    local rev_parse_command = { "git", "rev-parse", "--show-toplevel" }
    execute_command(rev_parse_command, cwd, callback, err_cb)
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

---Execute git blame
---@param file_path string relative file path
---@param cwd any where to execute the command
---@param a_commit string commit hash
---@param b_commit string commit hash
---@param callback fun(diff string[]) callback on exiting command with output string
---@param err_cb nil | fun(err) callback on error
function Git:diff(file_path, cwd, a_commit, b_commit, callback, err_cb)
    local diff_command = { "git", "--no-pager", "diff", "--unified=0", a_commit, b_commit, "--", file_path }
    execute_command(diff_command, cwd, callback, err_cb)
end

return Git
