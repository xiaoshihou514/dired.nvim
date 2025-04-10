local M = {}
local api = vim.api
local fs = require("dired.fs")
local util = require("dired.util")
local render_data = require("dired.render").info_providers_data
local getline = api.nvim_get_current_line
local autocmd = api.nvim_create_autocmd
local refresh = require("dired").refresh

local create_file_disabled_keys = { "<Up>", "<Down>", "<PageUp>", "<PageDown>" }

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

local function create_file()
    local line = getline()
    vim.print(line)
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
        local line = getline()
        if isdir(line) then
            vim.cmd.lcd(line)
            require("dired").refresh()
        else
            api.nvim_win_close(0, true)
            vim.cmd.edit(line)
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
        for _, k in ipairs(create_file_disabled_keys) do
            disable("i", k)
        end

        return "o"
    end, { expr = true })

    -- rename, select, move, delete, paste
end

return M
