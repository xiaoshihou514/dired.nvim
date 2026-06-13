local loaded = false
if loaded then
    return
end
loaded = true

local api, fn = vim.api, vim.fn

vim.g._dired_show_hidden = vim.g._dired_show_hidden or false
vim.g._dired_selected = vim.g._dired_selected or {}

api.nvim_create_user_command("Dired", function(opts)
    local cwd = opts.fargs[1] and fn.expand(opts.fargs[1]) or fn.getcwd()
    require("dired").open(cwd)
end, { nargs = "?" })

api.nvim_create_user_command("TutorDired", function()
    require("dired").tutor()
end, { nargs = 0 })

-- https://github.com/nvim-telescope/telescope-file-browser.nvim/blob/master/lua/telescope/_extensions/file_browser/config.lua#L73
local netrw_bufname
api.nvim_create_autocmd("BufEnter", {
    group = api.nvim_create_augroup("Dired", {}),
    desc = "Hijack netrw",
    pattern = "*",
    callback = vim.schedule_wrap(function()
        if vim.bo[0].filetype == "netrw" then
            return
        end
        local bufname = vim.api.nvim_buf_get_name(0)
        if fn.isdirectory(bufname) == 0 then
            _, netrw_bufname = pcall(fn.expand, "#:p:h")
            return
        end

        -- prevents reopening of file-browser if exiting without selecting a file
        if netrw_bufname == bufname then
            netrw_bufname = nil
            return
        else
            netrw_bufname = bufname
        end

        -- ensure no buffers remain with the directory name
        api.nvim_set_option_value("bufhidden", "wipe", { buf = 0 })

        require("dired").open(fn.fnamemodify(netrw_bufname, ":p:h"))
    end),
})

local highlights = {
    DiredDirectory = { link = "Directory" },
    DiredSymlink = { link = "NonText" },
    DiredExecutable = { link = "String" },
    DiredPermissions = { link = "Special" },
    DiredSize = { link = "String" },
    DiredUser = { link = "Function" },
    DiredDate = { link = "Keyword" },
    DiredHints = { link = "Comment" },
    DiredMode = { link = "ModeMsg" },
    DiredSelected = { link = "Visual" },
}

for name, attrs in pairs(highlights) do
    attrs.default = true
    vim.api.nvim_set_hl(0, name, attrs)
end
