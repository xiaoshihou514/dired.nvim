local M = {}

local api = vim.api

local function set_buffer_options()
    local opts = {
        number = false,
        relativenumber = false,
        spell = false,
        scrolloff = 0,
        conceallevel = 2,
        concealcursor = "nc",
    }
    for opt, val in pairs(opts) do
        api.nvim_set_option_value(opt, val, { win = 0 })
    end
end

---@param cmd string[]
---@param cwd string
---@param view table
---@param errormsg string
---@param on_success fun()?
function M.system(cmd, cwd, view, errormsg, on_success)
    vim.system(
        cmd,
        { cwd = cwd },
        vim.schedule_wrap(function(status)
            if status.code ~= 0 then
                vim.notify(errormsg, 3)
            end
            if on_success and type(on_success) == "function" then
                on_success()
            end
            M.refresh()
            vim.defer_fn(function()
                vim.fn.winrestview(view)
            end, 10)
        end)
    )
end

---@param dir string
function M.open(dir)
    local screen_height, screen_width = vim.o.lines, vim.o.columns
    local height = math.floor(screen_height * 0.8)
    local width = math.max(math.ceil(screen_width * 0.6), 65)
    local pad_top = math.floor((screen_height - height) / 2)
    local pad_side = math.floor((screen_width - width) / 2)
    api.nvim_open_win(api.nvim_create_buf(false, true), true, {
        relative = "editor",
        row = pad_top,
        col = pad_side,
        height = height,
        width = width,
    })
    api.nvim_command("silent! lcd " .. dir)
    set_buffer_options()
    vim.bo.ft = "dired"
end

function M.tutor()
    M.open(vim.fs.dirname(vim.fn.tempname()))
end

function M.refresh()
    local dir = vim.fn.getcwd()
    local view = api.nvim_win_call(0, vim.fn.winsaveview)
    set_buffer_options()
    local fds = require("dired.fs").list(dir)
    require("dired.render").draw(dir, fds)
    pcall(vim.fn.winrestview, view)
end

return M
