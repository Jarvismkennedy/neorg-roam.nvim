local M = {}

M.reload = function()
    print("reloading neorg")
    local reload = require("plenary.reload").reload_module
    reload("neorg")
    reload("neorg.modules.core.utils")
    reload("telescope._extensions.neorg.find_note")
    reload("telescope._extensions.neorg")
    require("neorg").setup({
        load = {
            ["core.defaults"] = {}, -- Loads default behaviour
            ["core.concealer"] = {}, -- Adds pretty icons to your documents
            ["core.dirman"] = { -- Manages Neorg workspaces
                config = {
                    workspaces = {
                        work = "~/Documents/notes/work",
                        personal = "~/Documents/notes/personal",
                        roam = "~/Documents/notes/roam",
                    },
                    default_workspace = "roam",
                },
            },
            ["core.integrations.roam"] = {},
        },
    })
end
return M
