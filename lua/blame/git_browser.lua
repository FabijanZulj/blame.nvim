local M = {}

---Parse git remote URL to extract host and repo path
---@param remote_url string
---@return {host: string, owner: string, repo: string} | nil
local function parse_remote_url(remote_url)
    local host, owner, repo = remote_url:match("git@([^:]+):([^/]+)/(.+)%.git")
    if host then
        return { host = host, owner = owner, repo = repo }
    end

    host, owner, repo = remote_url:match("https?://([^/]+)/([^/]+)/(.+)%.git")
    if host then
        return { host = host, owner = owner, repo = repo }
    end

    host, owner, repo = remote_url:match("https?://([^/]+)/([^/]+)/([^/%.]+)")
    if host then
        return { host = host, owner = owner, repo = repo }
    end

    host, owner, repo = remote_url:match("git@([^:]+):([^/]+)/([^/%.]+)")
    if host then
        return { host = host, owner = owner, repo = repo }
    end

    return nil
end

---Build commit URL based on git hosting provider
---@param parsed_remote {host: string, owner: string, repo: string}
---@param commit_hash string
---@return string | nil
local function build_commit_url(parsed_remote, commit_hash)
    local host = parsed_remote.host
    local owner = parsed_remote.owner
    local repo = parsed_remote.repo

    if host:match("github%.com") then
        return string.format(
            "https://github.com/%s/%s/commit/%s",
            owner,
            repo,
            commit_hash
        )
    end

    if host:match("gitlab%.com") or host:match("gitlab%.") then
        return string.format(
            "https://%s/%s/%s/-/commit/%s",
            host,
            owner,
            repo,
            commit_hash
        )
    end

    if host:match("bitbucket%.org") then
        return string.format(
            "https://bitbucket.org/%s/%s/commits/%s",
            owner,
            repo,
            commit_hash
        )
    end

    return string.format(
        "https://%s/%s/%s/commit/%s",
        host,
        owner,
        repo,
        commit_hash
    )
end

---Open URL in default browser
---@param url string
local function open_url(url)
    local cmd
    if vim.fn.has("mac") == 1 then
        cmd = { "open", url }
    elseif vim.fn.has("unix") == 1 then
        cmd = { "xdg-open", url }
    elseif vim.fn.has("win32") == 1 then
        cmd = { "cmd.exe", "/c", "start", url }
    else
        vim.notify(
            "Unsupported OS for opening browser",
            vim.log.levels.ERROR
        )
        return
    end

    vim.fn.jobstart(cmd, { detach = true })
end

---Get git remote URL for current repository
---@param cwd string
---@param callback fun(url: string)
---@param err_cb fun(err: string)
M.get_remote_url = function(cwd, callback, err_cb)
    local data
    local err_data
    vim.fn.jobstart({ "git", "remote", "get-url", "origin" }, {
        cwd = cwd,
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                return err_cb(
                    err_data and table.concat(err_data, " ")
                        or "Failed to get remote URL"
                )
            end
            if data and data[1] then
                callback(data[1])
            else
                err_cb("No remote URL found")
            end
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

---Open commit in browser
---@param commit_hash string
---@param cwd string
M.open_commit_in_browser = function(commit_hash, cwd)
    M.get_remote_url(cwd, function(remote_url)
        vim.schedule(function()
            local parsed = parse_remote_url(remote_url)
            if not parsed then
                vim.notify(
                    "Could not parse git remote URL: " .. remote_url,
                    vim.log.levels.WARN
                )
                return
            end

            local url = build_commit_url(parsed, commit_hash)
            if url then
                open_url(url)
                vim.notify("Opening commit in browser: " .. url)
            else
                vim.notify(
                    "Could not build commit URL for host: " .. parsed.host,
                    vim.log.levels.WARN
                )
            end
        end)
    end, function(err)
        vim.schedule(function()
            vim.notify(err, vim.log.levels.ERROR)
        end)
    end)
end

return M
