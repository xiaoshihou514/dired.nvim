local M = {}
M.info_providers_data = {}
M.ns = vim.api.nvim_create_namespace("Dired")
M.selns = vim.api.nvim_create_namespace("DiredSelected")
---@class FileEntry
---@field name string
---@field type string

local api = vim.api
local fs = require("dired.fs")
local util = require("dired.util")
local info = require("dired.info")

---@param str string
---@param len number
---@return string
local function pad(str, len)
    return str .. string.rep(" ", len - #str)
end

function M.extmark(...)
    api.nvim_buf_set_extmark(0, M.ns, ...)
end

function M.sel_extmark(...)
    api.nvim_buf_set_extmark(0, M.selns, ...)
end

---@param mode string?
function M.update_mode(mode)
    mode = mode or "NORMAL"
    local cwd = vim.fn.getcwd()
    cwd = cwd:gsub(vim.env.HOME, "~")

    local wc = api.nvim_win_get_config(0)
    if not wc.split then
        -- floating
        vim.wo[0].winbar = ("%%=%s%%="):format(cwd)
        api.nvim_win_set_config(0, {
            title = { { (" -- %s -- "):format(mode), "DiredMode" } },
        })
    else
        -- non floating
        vim.wo[0].winbar = ("%%=%s: -- %s --%%="):format(cwd, mode)
    end
end

---@param dir string
---@param files FileEntry[]
function M.draw(dir, files)
    local cwd = vim.fn.getcwd()

    -- clear buffer
    api.nvim_buf_set_lines(0, 0, -1, false, {})
    for _, e in ipairs(api.nvim_buf_get_extmarks(0, M.ns, 0, -1, {})) do
        api.nvim_buf_del_extmark(0, M.ns, e[1])
    end

    -- init provider data
    local providers = util.getopt("info")
    for _, provider in ipairs(providers) do
        M.info_providers_data[provider] = { len = 0 }
    end

    for idx, f in ipairs(files) do
        local line = idx - 1
        local shown = f.type == "directory" and f.name .. "/" or f.name
        api.nvim_buf_set_lines(0, line, line, true, { shown })

        if f.type == "directory" then
            -- apply directory highlight
            M.extmark(line, 0, {
                end_row = line,
                end_col = #shown,
                hl_group = "DiredDirectory",
            })
        elseif f.type == "link" then
            -- apply symlink highlight
            M.extmark(line, 0, {
                end_row = line,
                end_col = #shown,
                hl_group = "DiredSymlink",
            })

            M.extmark(line, #shown, {
                virt_text = { { "-> ", "Normal" }, { fs.linkdest(dir, f.name), "DiredSymlink" } },
                invalidate = true,
            })
        end

        -- selection indicator
        local path = vim.fs.joinpath(cwd, shown)
        if vim.g._dired_selected and vim.g._dired_selected[path] then
            -- selected
            M.extmark(line, 0, {
                end_col = #shown,
                hl_group = "DiredSelected",
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

    -- hook up info status, winbar and title
    vim.wo.statuscolumn = stc
    M.update_mode()
end

return M
