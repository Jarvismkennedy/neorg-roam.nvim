local M = {}

M.reload = function()
    print("reloading neorg")
    local reload = require("plenary.reload").reload_module
    reload("neorg")
    reload("neorg.modules.core.utils")
    require("neorg").setup({
        load = {
            ["core.defaults"] = {}, -- Loads default behaviour
            ["core.concealer"] = {
                config = {
                    icon_preset = "varied",
                },
            }, -- Adds pretty icons to your documents
            ["core.export"] = {},
            ["core.dirman"] = { -- Manages Neorg workspaces
                config = {
                    workspaces = {
                        work = "~/Documents/notes/work",
                        personal = "~/Documents/notes/personal",
                        roam = "~/Documents/notes/roam",
                        plugin_dev = "~/Documents/notes/plugin_dev",
                    },
                    default_workspace = "plugin_dev",
                },
            },
            ["core.looking-glass"] = {},
            ["core.integrations.roam"] = { config = { keymaps = {
                find_note = "<leader>nrf",
            } } },
        },
    })
end
return M
