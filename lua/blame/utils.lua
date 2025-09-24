local M = {}

local function relative_time(timestamp)
    local diff = os.time() - timestamp

    if diff < 60 then
        return diff .. " second" .. (diff ~= 1 and "s" or "") .. " ago"
    elseif diff < 3600 then
        local minutes = math.floor(diff / 60)
        return minutes .. " minute" .. (minutes ~= 1 and "s" or "") .. " ago"
    elseif diff < 86400 then
        local hours = math.floor(diff / 3600)
        return hours .. " hour" .. (hours ~= 1 and "s" or "") .. " ago"
    elseif diff < 2592000 then
        local days = math.floor(diff / 86400)
        return days .. " day" .. (days ~= 1 and "s" or "") .. " ago"
    elseif diff < 31536000 then
        local months = math.floor(diff / 2592000)
        return months .. " month" .. (months ~= 1 and "s" or "") .. " ago"
    else
        local years = math.floor(diff / 31536000)
        return years .. " year" .. (years ~= 1 and "s" or "") .. " ago"
    end
end

---Calculates the longest string in the string[]
---@param string_array string[]
---@return integer
M.longest_string_in_array = function(string_array)
    local longest = 0
    for _, value in ipairs(string_array) do
        if vim.fn.strdisplaywidth(value) > longest then
            longest = vim.fn.strdisplaywidth(value)
        end
    end
    return longest
end

--- Formats a timestamp using a format string.
--- If the format contains "%r", it will be replaced with a human-readable relative time.
--- Otherwise, it behaves like os.date.
---
--- @param format string: A format string (e.g. "%r", "%Y-%m-%d", "Committed %r")
--- @param timestamp number: A UNIX timestamp to format
--- @return string: Formatted date string
M.format_time = function(format, timestamp)
    if format:find("%%r") then
        return (format:gsub("%%r", relative_time(timestamp)))
    else
        return tostring(os.date(format, timestamp))
    end
end

--- Formats a timestamp as relative if < 1 month, else absolute
--- @param format string: Format string for absolute date
--- @param timestamp number: UNIX timestamp
--- @return string
M.format_recent_date = function(format, timestamp)
    local diff = os.time() - timestamp
    if diff < 2592000 then -- < 30 days
        return relative_time(timestamp)
    else
        return M.format_time(format, timestamp)
    end
end

return M
