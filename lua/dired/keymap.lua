local M = {}

local api = vim.api
local fs = require("dired.fs")
local util = require("dired.util")
local render = require("dired.render")
local render_data = render.info_providers_data
local getline = api.nvim_get_current_line
local getcwd = vim.fn.getcwd
local autocmd = api.nvim_create_autocmd
local join = vim.fs.joinpath
local refresh = require("dired").refresh
local dired_system = require("dired").system

-- stylua: ignore start
local create_file_disabled_keys = {
    "<Up>", "<Down>", "<PageUp>",
    "<PageDown>", "<C-c>", "<C-[>"
}
local normal_disabled = {
    "i", "a", "A", "s", "S", "R", "O",
    "r", "o", "<C-a>", "u"
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

local function index(xs, x)
    local res = -1
    for i, v in ipairs(xs) do
        if v == x then
            res = i
            break
        end
    end
    return res - 1
end

-- modified from runtime/lua/vim/lsp/buf.lua
---@return integer, integer
function M.range_from_selection()
    local start = vim.fn.getpos("v")
    local end_ = vim.fn.getpos(".")
    local start_row = start[2]
    local end_row = end_[2]
    if end_row < start_row then
        start_row, end_row = end_row, start_row
    end
    return start_row, end_row
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

local function ask(prompt, cb)
    vim.ui.input({ prompt = prompt }, function(confirm)
        if confirm ~= "y" then
            return
        end
        cb()
    end)
end

function M.create_bindings()
    local mapping = util.getopt("mapping")
    map("n", mapping.quit, vim.cmd.quit)
    map("n", "<Esc>", vim.cmd.quit)
    map("i", "<Esc>", function()
        vim.cmd.quit()
    end)

    M.create_nav_bindings(mapping)
    M.create_edit_bindings(mapping)
end

function M.create_nav_bindings(mapping)
    -- navigation bindings
    map("n", mapping.edit, function()
        local entry = join(vim.fn.getcwd(), getline())
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
            local entry = join(getcwd(), line)
            api.nvim_win_close(0, true)
            vim.cmd.vsplit(entry)
        end
    end)

    map("n", mapping.split, function()
        local line = getline()
        if not isdir(line) then
            local entry = join(getcwd(), line)
            api.nvim_win_close(0, true)
            vim.cmd.split(entry)
        end
    end)

    map("n", mapping.tabe, function()
        local line = getline()
        if not isdir(line) then
            local entry = join(getcwd(), line)
            api.nvim_win_close(0, true)
            vim.cmd.tabedit(entry)
        end
    end)

    map("n", mapping.up, function()
        vim.cmd.lcd("..")
        require("dired").refresh()
    end)
end

function M.create_edit_bindings(mapping)
    for _, k in ipairs(normal_disabled) do
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

    map({ "n", "x" }, mapping.select, function()
        local cwd = vim.fn.getcwd()
        local selected = {}
        local srow, _ = unpack(api.nvim_win_get_cursor(0))
        if vim.fn.mode() ~= "n" then
            local s, e = M.range_from_selection()
            srow = s
            selected = api.nvim_buf_get_lines(0, s - 1, e, true)
            api.nvim_input("<Esc>")
        else
            selected = { getline() }
        end

        local t = vim.g._dired_selected or {}
        for _, e in ipairs(selected) do
            local path = join(cwd, e)
            if not t[path] then
                -- select
                t[path] = true

                render.sel_extmark(index(selected, e) + srow - 1, 0, {
                    end_col = #e,
                    hl_group = "DiredSelected",
                })
            else
                -- unselect
                t[path] = nil

                local row = index(selected, e) + srow
                local id = unpack(
                    api.nvim_buf_get_extmarks(
                        0,
                        render.selns,
                        { row - 1, 0 },
                        { row + 1, 0 },
                        { limit = 1 }
                    )[1]
                )
                ---@diagnostic disable-next-line: param-type-mismatch
                api.nvim_buf_del_extmark(0, render.selns, id)
            end
        end
        vim.g._dired_selected = t
    end)

    -- move
    map("n", mapping.move, function()
        local cwd = getcwd()
        local view = api.nvim_win_call(0, vim.fn.winsaveview)
        local selected = vim.g._dired_selected or {}
        local paths = vim.tbl_keys(selected)
        if #paths == 0 then
            return
        end
        for _, f in ipairs(paths) do
            local to = join(cwd, vim.fn.fnamemodify(f, ":t"))
            if vim.uv.fs_stat(to) then
                ask('Overwrite "' .. to .. '"?', function()
                    dired_system(
                        { "/bin/mv", f, to },
                        cwd,
                        view,
                        ("Move failed: mv %s %s"):format(f, to)
                    )
                end)
            else
                dired_system(
                    { "/bin/mv", f, to },
                    cwd,
                    view,
                    ("Move failed: mv %s %s"):format(f, to)
                )
            end
        end
        vim.g._dired_selected = {}
    end)

    -- delete
    map("n", mapping.delete, function()
        local cwd = getcwd()
        local view = api.nvim_win_call(0, vim.fn.winsaveview)
        local selected = vim.g._dired_selected or {}
        local paths = vim.tbl_keys(selected)
        if #paths == 0 then
            return
        end
        local tostr = table.concat(paths, ", ")
        ask("Remove " .. tostr .. "?", function()
            dired_system(
                vim.list_extend({ "/bin/rm", "-rf" }, paths),
                cwd,
                view,
                ("Deletion failed: rm -rf %s"):format(tostr)
            )
            vim.g._dired_selected = {}
        end)
    end)

    -- paste (copy)
    map("n", mapping.paste, function()
        local cwd = getcwd()
        local view = api.nvim_win_call(0, vim.fn.winsaveview)
        local selected = vim.g._dired_selected or {}
        local paths = vim.tbl_keys(selected)
        if #paths == 0 then
            return
        end
        for _, f in ipairs(paths) do
            local to = join(cwd, vim.fn.fnamemodify(f, ":t"))
            if vim.uv.fs_stat(to) then
                ask('Overwrite "' .. to .. '"?', function()
                    dired_system(
                        { "/bin/cp", "-rf", f, to },
                        cwd,
                        view,
                        ("Copy failed: cp %s %s"):format(f, to)
                    )
                end)
            else
                dired_system(
                    { "/bin/cp", "-rf", f, to },
                    cwd,
                    view,
                    ("Copy failed: cp %s %s"):format(f, to)
                )
            end
        end
        vim.g._dired_selected = {}
    end)

    -- go to last entry
    map("n", mapping.goto_end, function()
        api.nvim_feedkeys("gg", "n", false)
        local count = 0
        for _, l in ipairs(api.nvim_buf_get_lines(0, 0, -1, false)) do
            if l == "" then
                break
            end
            count = count + 1
        end
        api.nvim_feedkeys(count - 1 .. "gj", "n", false)
    end)

    -- search
    map("n", mapping.search, function()
        local target = getcwd()
        vim.cmd.quit()
        local save = getcwd()
        vim.cmd.lcd(target)
        vim.cmd("Fzf files-cwd")
        vim.cmd.lcd(save)
    end)

    -- open in OS
    map("n", mapping.open_os, function()
        vim.system({ "xdg-open", getcwd() })
    end)

    -- toggle hidden
    map("n", mapping.toggle_hidden, function()
        vim.g._dired_show_hidden = not vim.g._dired_show_hidden
        refresh()
    end)
end

return M
