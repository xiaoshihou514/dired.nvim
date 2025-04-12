local M = {}

---@param opt string
function M.getopt(opt)
    local default = {
        info = { "permissions", "size", "user", "mtime" },
        binfts = { "pdf", "mp4", "mkv", "png", "svg" },
        mapping = {
            edit = "<cr>",
            split = "<C-o>",
            vsplit = "<C-x>",
            tabe = "<C-t>",
            edit_prefix = "g",
            split_prefix = "gs",
            vsplit_prefix = "gv",
            tabe_prefix = "gt",
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
