---@diagnostic disable: undefined-field
local M = {}

local ffi = require("ffi")
ffi.cdef([[
typedef unsigned int __uid_t;
typedef unsigned int __gid_t;
struct passwd {
  char *pw_name;
  char *pw_passwd;
  __uid_t pw_uid;
  __gid_t pw_gid;
  char *pw_gecos;
  char *pw_dir;	
  char *pw_shell;
};
struct passwd *getpwuid(__uid_t);
]])

local uv = vim.uv
local join = vim.fs.joinpath
local sep = uv.os_uname().sysname == "Windows" and "\\" or "/"

local function create_file(fname)
    local fd = uv.fs_open(fname, "w", 420)
    if fd then
        uv.fs_close(fd)
    end
end

---@param dir string
---@return FileEntry[]
function M.list(dir)
    local fd = assert(uv.fs_scandir(dir))
    local name, type = uv.fs_scandir_next(fd)
    local result = {}
    local show_hidden = vim.g._dired_show_hidden
    while name ~= nil do
        if show_hidden or name:sub(1, 1) ~= "." then
            table.insert(result, {
                name = name,
                type = type,
            })
        end
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
    local path = assert(uv.fs_readlink(join(dir, name)))
    return vim.startswith(path, "/") and path or "/" .. path
end

---@param dir string
---@param name string
---@return number
function M.size(dir, name)
    local path = join(dir, name)
    local fd = uv.fs_stat(path)
    if not fd then
        fd = uv.fs_stat(assert(uv.fs_readlink(path))) or { size = 0 }
    end
    return fd.size
end

---@param dir string
---@param name string
---@return number
function M.modt(dir, name)
    return uv.fs_stat(join(dir, name)).mtime.sec
end

---@param dir string
---@param name string
---@return number
function M.perms(dir, name)
    return uv.fs_stat(join(dir, name)).mode
end

---@param dir string
---@param name string
---@return string
function M.user(dir, name)
    return ffi.string(ffi.C.getpwuid(uv.fs_stat(join(dir, name)).uid).pw_name)
end

---@param name string
function M.create(name)
    local dir = vim.fn.getcwd()

    local subpaths = vim.split(name, sep)
    local file = table.remove(subpaths, #subpaths)
    local acc = ""
    for _, subdir in ipairs(subpaths) do
        acc = acc .. subdir .. sep
        assert(uv.fs_mkdir(join(dir, acc), 493))
    end
    if file ~= "" then
        create_file(join(dir, name))
    end
end

---@param dir string
---@param name string
---@return table|nil
function M.stat(dir, name)
    return uv.fs_stat(join(dir, name))
end

---@param name string
function M.imm_subpath(name)
    return name:sub(1, (name:find(sep) or -2) + 1)
end

---@param dir string
---@param from string
---@param to string
function M.rename(dir, from, to)
    uv.fs_rename(join(dir, from), join(dir, to))
end

---@param paths string[]  absolute paths
---@param cwd string
---@param on_done fun()?
function M.remove(paths, cwd, on_done)
    local session = (vim.env.DESKTOP_SESSION or ""):match("([^/%.]+)") or ""
    local function done()
        if on_done then
            on_done()
        end
    end
    if session:find("plasma") then
        local pending = #paths
        if pending == 0 then
            done()
            return
        end
        for _, p in ipairs(paths) do
            vim.system(
                { "kioclient", "move", "file://" .. p, "trash:/" },
                { cwd = cwd },
                vim.schedule_wrap(function()
                    pending = pending - 1
                    if pending == 0 then
                        done()
                    end
                end)
            )
        end
    else
        vim.system(
            vim.list_extend({ "/bin/rm", "-rf" }, paths),
            { cwd = cwd },
            vim.schedule_wrap(function()
                done()
            end)
        )
    end
end

return M
