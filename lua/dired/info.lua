---@class InfoProvider
---@field hlgroup string
---@field show fun(string, string): string

---@type table<string, InfoProvider>
local M = {}

local fs = require("dired.fs")

---@param size number
---@return string
local function format_size(size)
    if size < 1024 then
        return string.format("%dB", size)
    end

    local units = {
        { limit = 1024 * 1024 * 1024 * 1024, unit = "T" },
        { limit = 1024 * 1024 * 1024, unit = "G" },
        { limit = 1024 * 1024, unit = "M" },
        { limit = 1024, unit = "K" },
    }

    for _, unit in ipairs(units) do
        if size > unit.limit then
            local converted = size / unit.limit
            return string.format("%.2f%s", converted, unit.unit)
        end
    end

    -- unreachable
    return "NaN"
end

---@param timestamp number
---@return string
local function friendly_time(timestamp)
    local now = os.time()
    local diff = now - timestamp
    if diff < 60 then
        return string.format("%d secs ago", diff)
    elseif diff < 3600 then
        return string.format("%d mins ago", math.floor(diff / 60))
    elseif diff < 86400 then
        return string.format("%d hours ago", math.floor(diff / 3600))
    elseif diff < 86400 * 14 then -- two weeks show "X days ago"
        return string.format("%d days ago", math.floor(diff / 86400))
    else
        ---@type string
        return os.date("%Y-%-m-%-d", timestamp)
    end
end

M.size = {
    hlgroup = "DiredSize",
    show = function(dir, fname)
        return format_size(fs.size(dir, fname))
    end,
}

M.mtime = {
    hlgroup = "DiredDate",
    show = function(dir, fname)
        return friendly_time(fs.modt(dir, fname))
    end,
}

return M
