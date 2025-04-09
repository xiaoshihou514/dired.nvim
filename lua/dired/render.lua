local M = {}
---@class FileEntry
---@field name string
---@field type string

local api = vim.api
local ns = api.nvim_create_namespace("Dired")
local fs = require("dired.fs")

local function extmark(...)
    api.nvim_buf_set_extmark(0, ns, ...)
end

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
        return os.date("%Y-%-m-%-d", timestamp)
    end
end

---@param str string
---@param len number
---@return string
local function pad(str, len)
    return str .. string.rep(" ", len - #str)
end

---@param dir string
---@param files FileEntry[]
function M.draw(dir, files)
    -- clear buffer
    api.nvim_buf_set_lines(0, 0, -1, false, {})
    local sizes, size_maxlen = {}, 0
    local modts, modt_maxlen = {}, 0

    for line, f in ipairs(files) do
        local shown = f.type == "directory" and f.name .. "/" or f.name
        api.nvim_buf_set_lines(0, line, line, true, { shown })

        if f.type == "directory" then
            -- apply directory highlight
            extmark(line, 0, {
                end_row = line,
                end_col = #shown,
                hl_group = "DiredDirectory",
            })
        elseif f.type == "link" then
            -- apply symlink highlight
            extmark(line, 0, {
                end_row = line,
                end_col = #shown,
                hl_group = "DiredSymlink",
            })

            extmark(line, #shown, {
                virt_text = { { "-> ", "Normal" }, { fs.linkdest(dir, f.name), "DiredSymlink" } },
                invalidate = true,
            })
        end

        -- collect entry size
        local sz = format_size(fs.size(dir, f.name))
        table.insert(sizes, sz)
        size_maxlen = math.max(size_maxlen, #sz)

        -- collect mod time
        local time = friendly_time(fs.modt(dir, f.name))
        table.insert(modts, time)
        modt_maxlen = math.max(modt_maxlen, #time)
    end

    _G._dired_stc_size = function(line)
        return pad(sizes[line] or "", size_maxlen + 1)
    end
    _G._dired_stc_mtime = function(line)
        return pad(modts[line] or "", modt_maxlen + 2)
    end

    vim.wo.statuscolumn = "%#DiredDate#%{v:lua._dired_stc_mtime(v:lnum)}%*"
        .. "%#DiredSize#%{v:lua._dired_stc_size(v:lnum)}%*"

    -- delete first line
    api.nvim_buf_set_lines(0, 0, 1, true, {})
end

return M
