local M = {}

M.reload = function()
    print("reloading neorg")
    local reload = require("plenary.reload").reload_module
    reload("neorg")
    print("reload utils")
    reload("neorg.utils")
    print("reload find_note")
    reload("telescope._extensions.neorg.find_note")
    reload("telescope._extensions.neorg")
    print("require neorg")
    require("neorg").setup({
        load = {
            ["core.defaults"] = {}, -- Loads default behaviour
            ["core.concealer"] = {}, -- Adds pretty icons to your documents
            ["core.dirman"] = { -- Manages Neorg workspaces
                config = {
                    workspaces = {
                        work = "~/Documents/notes/work",
                        personal = "~/Documents/notes/personal",
                    },
                    default_workspace = "work",
                },
            },
            ["core.integrations.roam"] = {},
        },
    })
end
return M
