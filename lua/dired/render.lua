local M = {}
M.info_providers_data = {}
---@class FileEntry
---@field name string
---@field type string

local api = vim.api
local ns = api.nvim_create_namespace("Dired")
local fs = require("dired.fs")
local util = require("dired.util")
local info = require("dired.info")

local function extmark(...)
    api.nvim_buf_set_extmark(0, ns, ...)
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
    local providers = util.getopt("info")
    for _, provider in ipairs(providers) do
        M.info_providers_data[provider] = { len = 0 }
    end

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

        -- collect info
        for _, provider in ipairs(providers) do
            local data = info[provider].show(dir, shown)
            table.insert(M.info_providers_data[provider], data)
            M.info_providers_data[provider].len =
                math.max(M.info_providers_data[provider].len, #data)
        end
    end

    -- hook up statuscolumn with info provider
    local stc = ""
    for _, provider in ipairs(providers) do
        _G["_dired_stc_" .. provider] = function(line, vnum)
            return vnum == 0
                    and pad(
                        M.info_providers_data[provider][line] or "",
                        M.info_providers_data[provider].len + 2
                    )
                or ""
        end
        stc = stc
            .. ("%%#%s#%%{v:lua._dired_stc_%s(v:lnum,v:virtnum)}%%*"):format(
                info[provider].hlgroup,
                provider
            )
    end

    vim.wo.statuscolumn = stc

    -- delete first line
    api.nvim_buf_set_lines(0, 0, 1, true, {})
end

return M
