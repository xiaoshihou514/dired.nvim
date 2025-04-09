---@diagnostic disable: undefined-field
local M = {}

local uv = vim.uv
local sep = uv.os_uname().sysname == "Windows" and "\\" or "/"

local function concat(dir, f)
    return dir .. sep .. f
end

---@param dir string
---@return FileEntry[]
function M.list(dir)
    local fd = uv.fs_scandir(dir)
    local name, type = uv.fs_scandir_next(fd)
    local result = {}
    while name ~= nil do
        table.insert(result, {
            name = name,
            type = type,
        })
        name, type = uv.fs_scandir_next(fd)
    end

    table.sort(result, function(a, b)
        if a.type == b.type then
            if a.name:sub(1, 1) == "." and b.name:sub(1, 1) ~= "." then
                return true
            else
                return a.name < b.name
            end
        else
            return a.type == "directory" and b.type ~= "directory"
        end
    end)
    return result
end

---@param dir string
---@param name string
---@return string
function M.linkdest(dir, name)
    local path = uv.fs_readlink(concat(dir, name))
    return vim.startswith(path, "/") and path or "/" .. path
end

---@param dir string
---@param name string
---@return number
function M.size(dir, name)
    local path = concat(dir, name)
    local fd = uv.fs_stat(path)
    if not fd then
        fd = uv.fs_stat(uv.fs_readlink(path)) or { size = 0 }
    end
    return fd.size
end

---@param dir string
---@param name string
---@return number
function M.modt(dir, name)
    return uv.fs_stat(concat(dir, name)).mtime.sec
end

return M
