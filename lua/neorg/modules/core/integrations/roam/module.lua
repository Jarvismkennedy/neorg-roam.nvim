local neorg = require("neorg.core")
local module = neorg.modules.create("core.integrations.roam")
module.setup = function()
    print("setting up a module")
    return { success = true, requires = { "core.keybinds", "core.dirman" } }
end

module.load = function()
    print("loading a module")
end

module.private = {}
module.public = {
    neorg_find_note = function()
        -- could do it as dependency injection with dirman if needed
        local dirman = module.required["core.dirman"]
        local curr_wksp = dirman.get_current_workspace()
        local files = dirman.get_norg_files(curr_wksp[1])
    end,
}

vim.keymap.set("n", "<leader>hrr", ":lua require('dev').reload()<CR>")
vim.keymap.set("n", "<leader>nrf", module.public.neorg_find_note)
return module
