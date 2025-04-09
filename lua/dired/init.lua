local M = {}

local api = vim.api

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
        border = "single",
    })
    api.nvim_command("silent! lcd " .. dir)
    vim.bo.ft = "dired"
end

function M.refresh()
    local dir = vim.fn.getcwd()
    local fds = require("dired.fs").list(dir)
    require("dired.render").draw(dir, fds)
end

return M
