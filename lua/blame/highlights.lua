local M = {}

---@return string
local function random_rgb(custom_colors)
    if custom_colors and #custom_colors > 0 then
        local index = math.random(1, #custom_colors)
        return custom_colors[index]
    else
        local r = math.random(100, 255)
        local g = math.random(100, 255)
        local b = math.random(100, 255)
        return string.format("#%02X%02X%02X", r, g, b)
    end
end

---Highlights each unique hash with a random fg
---@param parsed_lines Porcelain[]
---@param config Config
M.create_highlights_per_hash = function(parsed_lines, config)
    for _, value in ipairs(parsed_lines) do
        local full_hash = value.hash
        local hash = string.sub(full_hash, 0, 7)
        if vim.fn.hlID(hash) == 0 then
            vim.api.nvim_set_hl(0, hash, {
                fg = random_rgb(config.colors),
                ctermfg = math.random(0, 255),
            })
        end
    end
end

---@class LineWithHl
---@field idx integer
---@field values {textValue: string, hl: string}[]
---@field format string

---@param  porcelain_lines Porcelain[]
---@param config Config
---@return LineWithHl[]
M.get_hld_lines_from_porcelain = function(porcelain_lines, config)
    local blame_lines = {}
    for idx, v in ipairs(porcelain_lines) do
        if
            config.merge_consecutive
            and idx > 1
            and porcelain_lines[idx - 1].hash == v.hash
        then
            blame_lines[#blame_lines + 1] = {
                idx = idx,
                values = {
                    {
                        textValue = "",
                        hl = nil,
                    },
                },
                format = "",
            }
        else
            local line_with_hl = config.format_fn(v, config, idx)
            blame_lines[#blame_lines + 1] = line_with_hl
        end
    end
    return blame_lines
end

---Applies the created highlights to a specified buffer
-- -@param lines string[]
-- -@param config Config
-- M.highlight_same_hash = function(lines, config, buffer)
--     for idx, line in ipairs(lines) do
--         local hash = line:match("^%S+")
--         if hash then
--             -- vim.api.nvim_buf_add_highlight(
--             --     buffer,
--             --     config.ns_id,
--             --     "Comment",
--             --     idx - 1,
--             --     0,
--             --     7
--             -- )
--             -- vim.api.nvim_buf_add_highlight(
--             --     buffer,
--             --     config.ns_id,
--             --     hash,
--             --     idx - 1,
--             --     8,
--             --     -1
--             -- )
--             vim.api.nvim_buf_add_highlight(
--                 buffer,
--                 config.ns_id,
--                 hash,
--                 idx - 1,
--                 0,
--                 -1
--             )
--         end
--     end
-- end

return M
