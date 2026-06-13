---@class InfoProvider
---@field hlgroup string
---@field show fun(string, string): string

---@type table<string, InfoProvider>
local M = {}

local fs = require("dired.fs")
local bit = require("bit")

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
        return string.format("%d秒前", diff)
    elseif diff < 3600 then
        return string.format("%d分钟前", math.floor(diff / 60))
    elseif diff < 86400 then
        return string.format("%d小时前", math.floor(diff / 3600))
    elseif diff < 86400 * 14 then
        return string.format("%d天前", math.floor(diff / 86400))
    else
        ---@type string
        return os.date("%Y年%-m月%-d日", timestamp)
    end
end

local function format_user_perms(mode)
    return table.concat({
        bit.band(mode, 0x100) ~= 0 and "r" or "-",
        bit.band(mode, 0x080) ~= 0 and "w" or "-",
        bit.band(mode, 0x040) ~= 0 and "x" or "-",
    })
end

M.permissions = {
    hlgroup = "DiredPermissions",
    show = function(dir, fname)
        return (vim.endswith(fname, "/") and "d" or ".") .. format_user_perms(fs.perms(dir, fname))
    end,
}

M.size = {
    hlgroup = "DiredSize",
    show = function(dir, fname)
        if vim.endswith(fname, "/") then
            return ""
        end
        return format_size(fs.size(dir, fname))
    end,
}

M.user = {
    hlgroup = "DiredUser",
    show = fs.user,
}

M.mtime = {
    hlgroup = "DiredDate",
    show = function(dir, fname)
        return friendly_time(fs.modt(dir, fname))
    end,
}

return M
