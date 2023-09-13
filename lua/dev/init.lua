local M = {}

M.reload = function()
    print("reloading neorg")
    local reload = require("plenary.reload").reload_module
    reload("neorg")
    reload("neorg.modules.core.utils")
    reload("neorg.modules.core.integrations.roam.module")
    reload("neorg.modules.core.integrations.roam.capture.module")
    require("neorg").setup({
        load = {
            ["core.defaults"] = {}, -- Loads default behaviour
            ["core.concealer"] = {
                config = {
                    icon_preset = "basic",
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
            ["core.integrations.roam"] = {
                config = {
                    capture_templates = {
                        {
                            name = "default",
                            lines = { "", "" },
                        },
                        {
                            name = "New Class Note",
                            file = "${title}_${date}",
                            lines = { "", "* ${heading1}", "" },
                        },
                    },
                },
            },
        },
    })
end
return M
