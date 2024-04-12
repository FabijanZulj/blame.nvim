local M = {}

---@param mode string|table
---@param bind_name string
---@param rhs string|function
---@param opts table|nil
---@param force_lhs string|nil
M.set_keymap = function(mode, bind_name, rhs, opts, config, force_lhs)
    if force_lhs ~= nil then
        vim.keymap.set(mode, force_lhs, rhs, opts)
        return
    end

    local bind_s = config.mappings[bind_name]
    if type(bind_s) == "table" then
        for _, bind in ipairs(bind_s) do
            vim.keymap.set(mode, bind, rhs, opts)
        end
    else
        vim.keymap.set(mode, bind_s, rhs, opts)
    end
end

return M
