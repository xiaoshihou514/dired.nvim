local M = {}

---@param opt string
function M.getopt(opt)
    local default = {
        -- info = { "permission", "size", "user", "mtime" },
        info = { "size", "mtime" },
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
