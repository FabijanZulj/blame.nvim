local M = {}

-- Utility to pick K maximally distant indices from a palette of M colors
local function pick_spread_indices(num_colors, num_commits)
    local indices = {}
    if num_commits == 1 then
        table.insert(indices, math.ceil(num_colors / 2))
    else
        for i = 1, num_commits do
            -- Spread indices evenly, centered
            local pos = (num_colors + 1) * i / (num_commits + 1)
            table.insert(indices, math.floor(pos + 0.5))
        end
    end
    return indices
end

local function palette_rgb(custom_colors, palette_indices, color_index)
    if custom_colors and #custom_colors > 0 then
        local index = palette_indices[color_index]
        return custom_colors[index]
    else
        local r = math.random(100, 255)
        local g = math.random(100, 255)
        local b = math.random(100, 255)
        return string.format("#%02X%02X%02X", r, g, b)
    end
end

---Highlights each unique hash with a color based on commit age
---@param parsed_lines Porcelain[]
---@param config Config
M.create_highlights_per_hash = function(parsed_lines, config)
    -- Collect unique hashes with their timestamps
    local hash_time_map = {}
    for _, value in ipairs(parsed_lines) do
        local full_hash = value.hash
        if not hash_time_map[full_hash] then
            hash_time_map[full_hash] = value.author_time or 0
        end
    end
    -- Sort hashes by timestamp (oldest first)
    local sorted_hashes = {}
    for hash, _ in pairs(hash_time_map) do
        table.insert(sorted_hashes, hash)
    end
    table.sort(sorted_hashes, function(a, b)
        return hash_time_map[a] < hash_time_map[b]
    end)
    -- Pick color indices for the number of unique commits
    local palette_indices = nil
    if config.colors and #config.colors > 0 then
        palette_indices = pick_spread_indices(#config.colors, #sorted_hashes)
    end
    -- Assign colors based on spread indices
    for color_index, full_hash in ipairs(sorted_hashes) do
        local hash = string.sub(full_hash, 0, 7)
        if vim.fn.hlID(hash) == 0 then
            vim.api.nvim_set_hl(0, hash, {
                fg = palette_rgb(config.colors, palette_indices, color_index),
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

    -- Calculate max width of each column and add padding to match all lengths
    local max_widths = {}
    for _, line in ipairs(blame_lines) do
        for col_idx, value in ipairs(line.values) do
            local width = vim.fn.strdisplaywidth(value.textValue)
            if value.textValue == "Not commited" then
                width = 0
            end
            max_widths[col_idx] = math.max(max_widths[col_idx] or 0, width)
        end
    end

    for _, line in ipairs(blame_lines) do
        if #line.values > 0 and line.format ~= "" then
            local format_parts = {}
            for col_idx = 1, #line.values do
                if col_idx == #line.values then
                    table.insert(format_parts, "%s")
                else
                    table.insert(format_parts, string.format("%%-%ds", max_widths[col_idx]))
                end
            end
            line.format = table.concat(format_parts, "  ")
        end
    end

    return blame_lines
end

return M
