local M = {}
local api = vim.api
local fs = require("dired.fs")
local util = require("dired.util")
local render_data = require("dired.render").info_providers_data
local getline = api.nvim_get_current_line
local autocmd = api.nvim_create_autocmd
local refresh = require("dired").refresh

-- stylua: ignore start
local create_file_disabled_keys = {
    "<Up>", "<Down>", "<PageUp>",
    "<PageDown>", "<C-c>", "<C-[>"
}
-- stylua: ignore end

local function map(mode, lhs, rhs, opts)
    opts = opts or {}
    opts.buffer = true
    vim.keymap.set(mode, lhs, rhs, opts)
end

local function unmap(mode, lhs, opts)
    opts = opts or {}
    opts.buffer = true
    vim.keymap.del(mode, lhs, opts)
end

local function disable(mode, key)
    map(mode, key, "<Nop>")
end

local function enable(mode, key)
    unmap(mode, key)
end

local function isdir(line)
    return vim.endswith(line, "/")
end

local function open(file)
    local binfts = util.getopt("binfts")
    if vim.tbl_contains(binfts, vim.fn.fnamemodify(file, ":e")) then
        vim.ui.open(file)
    else
        vim.cmd.edit(file)
    end
end

local function create_file()
    local line = getline()
    if line == "" then
        -- restore prev data
        local row, _ = unpack(api.nvim_win_get_cursor(0))
        api.nvim_buf_set_lines(0, row - 1, row, true, {})
        for _, v in pairs(render_data) do
            table.remove(v, row)
        end
        return
    end

    fs.create(line)
    vim.defer_fn(function()
        refresh()
        -- put cursor on newly created entry
        for lnum, l in ipairs(api.nvim_buf_get_lines(0, 0, -1, false)) do
            if l == fs.imm_subpath(line) then
                api.nvim_win_set_cursor(0, { lnum, 0 })
                api.nvim_input("zz")
            end
        end
    end, 10)

    for _, k in ipairs(create_file_disabled_keys) do
        enable("i", k)
    end
    api.nvim_input("<Esc>")
end

function M.create_bindings()
    map("n", "q", vim.cmd.quit)
    M.create_nav_bindings()
    M.create_edit_bindings()
end

function M.create_nav_bindings()
    local mapping = util.getopt("mapping")

    -- navigation bindings
    map("n", mapping.edit, function()
        local entry = fs.concat(vim.fn.getcwd(), getline())
        if isdir(entry) then
            vim.cmd.lcd(entry)
            require("dired").refresh()
        else
            api.nvim_win_close(0, true)
            open(entry)
        end
    end)

    map("n", mapping.vsplit, function()
        local line = getline()
        if not isdir(line) then
            api.nvim_win_close(0, true)
            vim.cmd.vsplit(line)
        end
    end)

    map("n", mapping.split, function()
        local line = getline()
        if not isdir(line) then
            api.nvim_win_close(0, true)
            vim.cmd.split(line)
        end
    end)

    map("n", mapping.tabe, function()
        local line = getline()
        if not isdir(line) then
            api.nvim_win_close(0, true)
            vim.cmd.tabedit(line)
        end
    end)

    map("n", "-", function()
        vim.cmd.lcd("..")
        require("dired").refresh()
    end)
end

function M.create_edit_bindings()
    local disabled = { "i", "a", "A", "s", "S", "R", "O" }
    for _, k in ipairs(disabled) do
        disable("n", k)
    end

    map("n", "o", function()
        local row, _ = unpack(api.nvim_win_get_cursor(0))
        for _, v in pairs(render_data) do
            table.insert(v, row + 1, "")
        end

        autocmd("ModeChanged", {
            pattern = "i:*",
            once = true,
            callback = create_file,
        })
        map("i", "<cr>", "<Esc>")

        local function wrap(key)
            return function()
                local _, col = unpack(api.nvim_win_get_cursor(0))
                if col == 0 then
                    return ""
                else
                    return key
                end
            end
        end
        for _, k in ipairs({ "<BS>", "<C-h>", "<C-w>" }) do
            map("i", k, wrap(k), { expr = true })
        end

        for _, k in ipairs(create_file_disabled_keys) do
            disable("i", k)
        end

        return "o"
    end, { expr = true })

    -- rename, select, move, delete, paste
end

return M
