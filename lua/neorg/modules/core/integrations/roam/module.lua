local neorg = require("neorg.core")
local module = neorg.modules.create("core.integrations.roam")
module.setup = function()
    return { success = true, requires = { "core.keybinds", "core.dirman", "core.esupports.metagen" } }
end

module.load = function()
    -- should load the config, auto sync the db, etc,
end

module.private = {
    config = {
        select_prompt = "<C-c>",
    },
    generate_picker = function()
        local pickers = require("telescope.pickers")
        local finders = require("telescope.finders")
        local sorter = require("telescope.sorters")
        local make_entry = require("telescope.make_entry")
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")

        local dirman = module.required["core.dirman"]
        if dirman == nil then
            return error("This module requires core.dirman")
        end
        local curr_wksp = dirman.get_current_workspace()
        -- replace this with a sql lite db call later
        local files = dirman.get_norg_files(curr_wksp[1])

        return function(action)
            opts = opts or {}
            return pickers.new(opts, {
                prompt_title = "colors",
                attach_mappings = function(prompt_bufnr, map)
                    map({ "i", "n" }, module.private.config.select_prompt, function()
                        local current_picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
                        local prompt = current_picker:_get_prompt()
                        action(prompt, nil)
                        actions.close(prompt_bufnr)
                    end)
                    actions.select_default:replace(function()
                        local current_picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
                        local prompt = current_picker:_get_prompt()

                        local selection = action_state.get_selected_entry()
                        --
                        actions.close(prompt_bufnr)
                        action(prompt, selection)
                    end)

                    return true
                end,
                sorter = sorter.get_fzy_sorter(opts),
                finder = finders.new_table({
                    results = files,
                    entry_maker = make_entry.gen_from_file({ cwd = curr_wksp[2] }),
                }),
            })
        end
    end,
}
module.public = {
    find_note = function()
        local picker = module.private.generate_picker()
        local action = function(prompt, selection)
            if selection == nil then
                if prompt == "" or prompt == nil then
                    return
                end
                vim.print("you choose: " .. prompt)
                return
            end
            vim.print(selection)
        end
        picker(action):find()
    end,

    -- captures
    -- select a note to capture to.
    open_roam_capture = function() end,
    -- capture to workspace index.
    open_capture = function() end,
    cancel_capture = function() end,
    save_capture = function() end,
    --

    insert_link = function() end,
    get_back_links = function() end,
    db_sync = function() end,
    db_sync_workspace = function(wksp) end,
}

vim.keymap.set("n", "<leader>hrr", ":lua require('dev').reload()<CR>")
vim.keymap.set("n", "<leader>nrf", module.public.find_note)

return module
