local highlights = require("blame.highlights")
local utils = require("blame.utils")
---@class VirtualView : BlameView
---@field config Config
---@field original_buffer integer
---@field isopen boolean

local VirtualView = {}

---@return VirtualView
function VirtualView:new(config)
    local o = {}
    setmetatable(o, { __index = self })
    o.config = config
    o.isopen = false
    return o
end

---@param porcelain_lines Porcelain[]
function VirtualView:open(porcelain_lines)
    highlights.create_highlights_per_hash(porcelain_lines, self.config)
    self.original_buffer = vim.api.nvim_win_get_buf(0)
    local lines_with_hls =
        highlights.get_hld_lines_from_porcelain(porcelain_lines, self.config)

    if self.config.virtual_style == "float" then
        self:add_padding(lines_with_hls)
    end

    for _, line in pairs(lines_with_hls) do
        local line_to_show = {}
        for _, c in pairs(line.values) do
            table.insert(line_to_show, { c.textValue, c.hl })
            table.insert(line_to_show, { " " })
        end
        vim.api.nvim_buf_set_extmark(
            self.original_buffer,
            self.config.ns_id,
            line.idx - 1,
            0,
            {
                virt_text_pos = "right_align",
                virt_text = line_to_show,
                right_gravity = false,
            }
        )
    end
    self.isopen = true
end

---@param lines_with_hls LineWithHl[]
function VirtualView:add_padding(lines_with_hls)
    local buf_lines =
        vim.api.nvim_buf_get_lines(self.original_buffer, 0, -1, false)
    local longest_line = utils.longest_string_in_array(buf_lines)
    local window_width = vim.api.nvim_win_get_width(0)

    for _, line in pairs(lines_with_hls) do
        local text_fragments = {}
        for _, c in pairs(line.values) do
            table.insert(text_fragments, c.textValue)
        end

        local full_line = table.concat(text_fragments, " ")
        local content_length = vim.fn.strdisplaywidth(full_line)

        local padding_needed = window_width - longest_line - content_length - 10
        line.values[#line.values].textValue = line.values[#line.values].textValue
            .. string.rep(" ", padding_needed)
    end
end

function VirtualView:close()
    vim.api.nvim_buf_clear_namespace(
        self.original_buffer,
        self.config.ns_id,
        0,
        -1
    )
    self.isopen = false
end

function VirtualView:is_open()
    return self.isopen
end

-- local function should_skip(blames, index)
--     if index ~= 1 then
--         local hash = string.sub(blames[index]["hash"], 0, 7)
--         local prev_hash = string.sub(blames[index - 1]["hash"], 0, 7)
--         return hash == prev_hash
--     end
--     return false
-- end

---@class Line
---@field idx integer
---@field author {value: string, hl: string}
---@field date {value: string, hl: string}
---@field hash {value: string, hl: string}
-- function VirtualView:create_lines(blame_lines)
--     local lines = {}
--     for i, value in ipairs(blame_lines) do
--         local skip = false
--         if self.config.merge_consecutive then
--             skip = should_skip(blame_lines, i)
--         end
--         local hash = string.sub(value["hash"], 0, 7)
--         local is_not_commited = hash == "0000000"
--         if not (is_not_commited or skip) then
--             table.insert(lines, {
--                 idx = i,
--                 author = {
--                     value = value["author"] .. "  ",
--                     hl = hash,
--                 },
--                 date = {
--                     value = os.date(
--                         self.config.date_format .. "  ",
--                         value["committer-time"]
--                     ),
--                     hl = hash,
--                 },
--                 hash = {
--                     value = hash,
--                     hl = "Comment",
--                 },
--             })
--         end
--     end
--     return lines
-- end

-- -@param blame_lines Porcelain[]
-- -@return table
-- function VirtualView:create_lines_with_padding(blame_lines)
--     local mapped_lines = {}
--     local lines = vim.api.nvim_buf_get_lines(self.original_buffer, 0, -1, false)
--     local longest_line = utils.longest_string_in_array(lines)
--
--     for i, value in ipairs(blame_lines) do
--         local skip = false
--         if self.config.merge_consecutive then
--             skip = should_skip(blame_lines, i)
--         end
--         local hash = string.sub(value["hash"], 0, 7)
--         local is_not_commited = hash == "00000000"
--
--         local author = value["author"] .. " "
--         local date =
--             os.date(self.config.date_format .. "  ", value["committer-time"])
--         local hash_content = hash
--
--         local content_length =
--             vim.fn.strdisplaywidth(author .. date .. hash_content)
--         local window_width = vim.api.nvim_win_get_width(0)
--
--         local padding_needed = window_width - longest_line - content_length - 8
--
--         if not (is_not_commited or skip) then
--             table.insert(mapped_lines, {
--                 idx = i,
--                 author = {
--                     value = author,
--                     hl = hash,
--                 },
--                 date = {
--                     value = date,
--                     hl = hash,
--                 },
--                 hash = {
--                     value = hash_content .. string.rep(" ", padding_needed),
--                     hl = "DimHashBlame",
--                 },
--
--                 content = value["content"],
--             })
--         end
--     end
--     return mapped_lines
-- end

return VirtualView
