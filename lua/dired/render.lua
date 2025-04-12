local M = {}
M.info_providers_data = {}
---@class FileEntry
---@field name string
---@field type string

local api = vim.api
local fs = require("dired.fs")
local util = require("dired.util")
local info = require("dired.info")

local ns = api.nvim_create_namespace("Dired")
-- stylua: ignore start
local hints = {
    "a", "s", "d", "f", "g", "h", "j", "k", "l", ";", "'", "q", "w",
    "e", "r", "t", "z", "x", "c", "v", "y", "u", "i", "o", "p", "b",
    "n", "m",
}
-- stylua: ignore end

local function extmark(...)
    api.nvim_buf_set_extmark(0, ns, ...)
end

---@param str string
---@param len number
---@return string
local function pad(str, len)
    return str .. string.rep(" ", len - #str)
end

---@param mode string?
function M.update_winbar(mode)
    mode = mode or "Normal"
    local cwd = vim.fn.getcwd()
    cwd = cwd:gsub(vim.env.HOME, "~")

    vim.wo[0].winbar = ("%%=%s: -- %s --%%="):format(cwd, mode)
end

---@param dir string
---@param files FileEntry[]
function M.draw(dir, files)
    local mapping = util.getopt("mapping")

    -- clear buffer
    api.nvim_buf_set_lines(0, 0, -1, false, {})
    for _, e in ipairs(api.nvim_buf_get_extmarks(0, ns, 0, -1, {})) do
        api.nvim_buf_del_extmark(0, ns, e[1])
    end

    -- init provider data
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

    -- create quick keymaps if all entries are within viewport
    if #files < api.nvim_win_get_height(0) and #files < #hints then
        for i = 1, #files do
            extmark(i, 0, {
                virt_text_pos = "right_align",
                virt_text = { { "[" .. hints[i] .. "]", "DiredHints" } },
            })
        end

        for key, v in pairs({
            [mapping.edit_prefix] = { mapping.edit, "Quick-Edit" },
            [mapping.split_prefix] = { mapping.split, "Quick-Split" },
            [mapping.vsplit_prefix] = { mapping.vsplit, "Quick-Vsplit" },
            [mapping.tabe_prefix] = { mapping.tabe, "Quick-Tabedit" },
        }) do
            local binding, desc = unpack(v)
            vim.keymap.set("n", key, function()
                M.update_winbar(desc)
                vim.defer_fn(function()
                    local k = vim.fn.getchar(-1, { number = false })
                    for i, c in ipairs(hints) do
                        if i > #files then
                            M.update_winbar()
                            return
                        end
                        if c == k then
                            api.nvim_win_set_cursor(0, { i, 0 })
                            api.nvim_input(binding)
                            M.update_winbar()
                            return
                        end
                    end
                end, 10)
            end, { buffer = true })
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
    M.update_winbar()

    -- delete first line
    api.nvim_buf_set_lines(0, 0, 1, true, {})
end

return M
