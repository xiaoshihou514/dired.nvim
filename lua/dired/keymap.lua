local M = {}
local api = vim.api

local function map(mode, lhs, rhs, opts)
    opts = opts or {}
    opts.buffer = true
    vim.keymap.set(mode, lhs, rhs, opts)
end

local function disable(mode, key)
    map(mode, key, "<Nop>")
end

local function getline()
    local row, _ = unpack(api.nvim_win_get_cursor(0))
    return unpack(api.nvim_buf_get_lines(0, row - 1, row, true))
end

local function isdir(line)
    return vim.endswith(line, "/")
end

function M.create_bindings()
    M.create_nav_bindings()
    M.create_edit_bindings()
end

function M.create_nav_bindings()
    -- navigation bindings
    map("n", "<cr>", function()
        local line = getline()
        if isdir(line) then
            vim.cmd.lcd(line)
            require("dired").refresh()
        else
            api.nvim_win_close(0, true)
            vim.cmd.edit(line)
        end
    end)

    map("n", "-", function()
        vim.cmd.lcd("..")
        require("dired").refresh()
    end)

    map("n", "<C-v>", function()
        local line = getline()
        if not isdir(line) then
            api.nvim_win_close(0, true)
            vim.cmd.vsplit(line)
        end
    end)

    map("n", "<C-s>", function()
        local line = getline()
        if not isdir(line) then
            api.nvim_win_close(0, true)
            vim.cmd.split(line)
        end
    end)
end

function M.create_edit_bindings()
    disable("n", "q")

    map("n", "o", function()
        return "Go"
    end, { expr = true })
end

return M
