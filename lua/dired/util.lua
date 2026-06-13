local M = {}

---@param opt string
function M.getopt(opt)
    local default = {
        info = { "permissions", "size", "mtime" },
        binfts = { "pdf", "mp4", "mkv", "png", "svg" },
        mapping = {
            quit = "q",
            up = "-",
            edit = "<cr>",
            split = "<C-o>",
            vsplit = "<C-x>",
            tabe = "<C-t>",

            create = "c",
            rename = "r",
            select = " ",
            move = "m",
            delete = "d",
            paste = "p",
            goto_end = "G",
            search = "/",
            open_os = "O",
            toggle_hidden = "H",
        },
    }
    if
        not vim.g.dired_config
        or type(vim.g.dired_config) ~= "table"
        or vim.g.dired_config[opt] == nil
    then
        return default[opt]
    else
        return vim.g.dired_config[opt]
    end
end

return M
