local M = {}
local api = vim.api
local fs = require("dired.fs")
local util = require("dired.util")
local render = require("dired.render")
local render_data = render.info_providers_data
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

local function exit_limited_insert_mode()
    for _, k in ipairs(create_file_disabled_keys) do
        enable("i", k)
    end
    render.update_mode()
    api.nvim_input("<Esc>")
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
        render.update_mode()
        return
    end

    fs.create(line)
    -- HACK
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

    exit_limited_insert_mode()
end

---@param from string
---@return fun()
local function rename_file(from)
    return function()
        local line = getline()
        if line == "" then
            local row, _ = unpack(api.nvim_win_get_cursor(0))
            api.nvim_buf_set_lines(0, row - 1, row, true, { from })
            render.update_mode()
            return
        end

        local dir = vim.fn.getcwd()
        fs.rename(dir, from, line)
        exit_limited_insert_mode()
    end
end

local function prepare_limited_insert_mode(cb)
    autocmd("ModeChanged", {
        pattern = "*:n",
        once = true,
        callback = cb,
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
end

function M.create_bindings()
    local mapping = util.getopt("mapping")
    map("n", mapping.quit, vim.cmd.quit)

    M.create_nav_bindings(mapping)
    M.create_edit_bindings(mapping)
end

function M.create_nav_bindings(mapping)
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

    map("n", mapping.create, function()
        vim.cmd.lcd("..")
        require("dired").refresh()
    end)
end

function M.create_edit_bindings(mapping)
    local disabled = { "i", "a", "A", "s", "S", "R", "O", "r", "o" }
    for _, k in ipairs(disabled) do
        disable("n", k)
    end

    map("n", mapping.create, function()
        local row, _ = unpack(api.nvim_win_get_cursor(0))
        for _, v in pairs(render_data) do
            table.insert(v, row + 1, "")
        end

        prepare_limited_insert_mode(create_file)

        render.update_mode("INSERT")
        return "o"
    end, { expr = true })

    map("n", mapping.rename, function()
        prepare_limited_insert_mode(rename_file(getline()))

        render.update_mode("RENAME")
        return "0v$h<C-g>"
    end, { expr = true })

    -- select, move, delete, paste
end

return M
