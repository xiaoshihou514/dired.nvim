local api = vim.api
local uv = vim.uv
local same = assert.are.same
local join = vim.fs.joinpath

local test_dir = "/tmp/dired-test/integration"
local saved_cwd

local function clean_dir(dir)
    local ok, fd = pcall(uv.fs_scandir, dir)
    if not ok or not fd then
        return
    end
    while true do
        local name, type = uv.fs_scandir_next(fd)
        if not name then
            break
        end
        local path = join(dir, name)
        if type == "directory" then
            clean_dir(path)
        else
            uv.fs_unlink(path)
        end
    end
    uv.fs_rmdir(dir)
end

local function setup_fixtures()
    clean_dir(test_dir)
    uv.fs_mkdir(test_dir, 493)
    for _, name in ipairs({ "a.txt", "b.lua", "c.md" }) do
        local fd
        pcall(function()
            fd = uv.fs_open(join(test_dir, name), "w", 420)
        end)
        if fd then
            uv.fs_write(fd, name, -1)
            uv.fs_close(fd)
        end
    end
    uv.fs_mkdir(join(test_dir, "sub"), 493)
    pcall(function()
        local fd = uv.fs_open(join(test_dir, "sub", "inner.txt"), "w", 420)
        if fd then
            uv.fs_close(fd)
        end
    end)
    pcall(function()
        local fd = uv.fs_open(join(test_dir, ".hidden"), "w", 420)
        if fd then
            uv.fs_close(fd)
        end
    end)
end

local function cd_test_dir()
    saved_cwd = vim.fn.getcwd()
    vim.cmd("cd " .. test_dir)
end

local function restore_cwd()
    if saved_cwd then
        vim.cmd("cd " .. saved_cwd)
        saved_cwd = nil
    end
end

describe("dired", function()
    before_each(function()
        setup_fixtures()
        vim.g._dired_show_hidden = false
        vim.g._dired_selected = {}
    end)

    after_each(function()
        clean_dir(test_dir)
        restore_cwd()
    end)

    describe("fs", function()
        it("lists files groupedirs first, alphabetical", function()
            local fs = require("dired.fs")
            local entries = fs.list(test_dir)
            same("sub", entries[1].name)
            same("directory", entries[1].type)
            same("a.txt", entries[2].name)
            same("b.lua", entries[3].name)
            same("c.md", entries[4].name)
            same(4, #entries)
        end)

        it("hides dotfiles by default", function()
            local fs = require("dired.fs")
            local entries = fs.list(test_dir)
            for _, e in ipairs(entries) do
                assert.are_not_equal(".hidden", e.name)
            end
        end)

        it("shows dotfiles when _dired_show_hidden is true", function()
            vim.g._dired_show_hidden = true
            local fs = require("dired.fs")
            local entries = fs.list(test_dir)
            local found = false
            for _, e in ipairs(entries) do
                if e.name == ".hidden" then
                    found = true
                    break
                end
            end
            same(true, found)
        end)

        it("creates a file", function()
            cd_test_dir()
            local fs = require("dired.fs")
            fs.create("hello.txt")
            local stat = uv.fs_stat(join(test_dir, "hello.txt"))
            assert.are_not_equal(nil, stat)
            same("file", stat.type)
        end)

        it("creates nested file and directory", function()
            cd_test_dir()
            local fs = require("dired.fs")
            fs.create("a/b/c.txt")
            same("directory", uv.fs_stat(join(test_dir, "a")).type)
            same("directory", uv.fs_stat(join(test_dir, "a", "b")).type)
            same("file", uv.fs_stat(join(test_dir, "a", "b", "c.txt")).type)
        end)

        it("renames a file", function()
            cd_test_dir()
            local fs = require("dired.fs")
            fs.rename(test_dir, "a.txt", "renamed.txt")
            same(nil, uv.fs_stat(join(test_dir, "a.txt")))
            same("file", uv.fs_stat(join(test_dir, "renamed.txt")).type)
        end)

        it("reports permissions mode", function()
            local fs = require("dired.fs")
            local mode = fs.perms(test_dir, "a.txt")
            same("number", type(mode))
        end)

        it("reports file size", function()
            local fs = require("dired.fs")
            local size = fs.size(test_dir, "a.txt")
            same(true, size > 0)
        end)

        it("reports modification time", function()
            local fs = require("dired.fs")
            local mtime = fs.modt(test_dir, "a.txt")
            same("number", type(mtime))
        end)
    end)

    describe("info", function()
        it("formats size for files only", function()
            local info = require("dired.info")
            local size_dir = info.size.show(test_dir, "sub/")
            same("", size_dir)

            local size_file = info.size.show(test_dir, "a.txt")
            same(false, size_file == "")
        end)

        it("formats permissions as .rwx for files, drwx for dirs", function()
            local info = require("dired.info")
            local perms_dir = info.permissions.show(test_dir, "sub/")
            same("drwx", perms_dir)

            local perms_file = info.permissions.show(test_dir, "a.txt")
            same(".rw-", perms_file)
        end)

        it("formats time", function()
            local info = require("dired.info")
            local recent = info.mtime.show(test_dir, "a.txt")
            same(true, recent:find("秒前") ~= nil or recent:find("分钟前") ~= nil
                or recent:find("小时前") ~= nil or recent:find("天前") ~= nil
                or recent:find("年") ~= nil)
        end)
    end)

    describe("render", function()
        it("draws files into buffer with correct order", function()
            local render = require("dired.render")
            local fs = require("dired.fs")

            local buf = api.nvim_create_buf(false, true)
            api.nvim_set_current_buf(buf)

            local entries = fs.list(test_dir)
            render.draw(test_dir, entries)

            local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
            same("sub/", lines[1])
            same("a.txt", lines[2])
            same("b.lua", lines[3])
            same("c.md", lines[4])
            same(4, #lines)
        end)

        it("sets extmarks for directories", function()
            local render = require("dired.render")
            local fs = require("dired.fs")

            local buf = api.nvim_create_buf(false, true)
            api.nvim_set_current_buf(buf)

            local entries = fs.list(test_dir)
            render.draw(test_dir, entries)

            local extmarks = api.nvim_buf_get_extmarks(buf, render.ns, 0, -1, {})
            same(true, #extmarks > 0)
        end)

        it("populates statuscolumn data", function()
            local render = require("dired.render")
            local fs = require("dired.fs")

            local buf = api.nvim_create_buf(false, true)
            api.nvim_set_current_buf(buf)

            local entries = fs.list(test_dir)
            render.draw(test_dir, entries)

            local perms = render.info_providers_data["permissions"]
            same(4, #perms)
            same("drwx", perms[1]:sub(1, 4))
            same(".rw-", perms[2]:sub(1, 4))

            local size = render.info_providers_data["size"]
            same("", size[1])
            same(true, size[2] ~= "")
        end)
    end)
end)
