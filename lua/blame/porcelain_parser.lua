local M = {}

---@class Porcelain
---@field author string
---@field author_email string
---@field author_time number
---@field author_tz string
---@field committer string
---@field committer_mail string
---@field committer_time number
---@field committer_tz string
---@field filename string
---@field hash string
---@field previous string
---@field summary string
---@field content string

---Parses raw porcelain data (string[]) into an array of tables for each line containing the commit data
---@param blame_porcelain string[]
---@return Porcelain[]
M.parse_porcelain = function(blame_porcelain)
    local all_lines = {}
    for _, entry in ipairs(blame_porcelain) do
        local ident = entry:match("^%S+")
        if not ident then
            all_lines[#all_lines].content = entry
        elseif #ident == 40 then
            table.insert(all_lines, { hash = ident })
        else
            ident = ident:gsub("-", "_")

            local info = string.sub(entry, #ident + 2, -1)
            if ident == "author_time" or ident == "committer_time" then
                all_lines[#all_lines][ident] = tonumber(info)
            else
                all_lines[#all_lines][ident] = info
            end
        end
    end
    return all_lines
end

return M
