local neorg = require("neorg.core")
local utils = require("neorg.modules.core.utils")
local module = neorg.modules.create("core.integrations.roam")
module.config = {}
module.setup = function()
    return {
        success = true,
        requires = {
            "core.keybinds",
            "core.dirman",
            "core.esupports.metagen",
            "core.integrations.roam.capture",
        },
    }
end
module.neorg_post_load = function()
    -- set the keybind for pulling up telescope
    vim.keymap.set("n", module.config.public.keymaps.find_note, module.public.find_note)
    vim.keymap.set("n", module.config.public.keymaps.capture_note, module.public.capture_note)
    vim.keymap.set("n", module.config.public.keymaps.capture_index, module.public.capture_index)
end
module.load = function()
    module.required["core.integrations.roam.capture"].set_keymaps(module.config.public.keymaps)
    -- register keybinds
    local keybinds = module.required["core.keybinds"]
    keybinds.register_keybinds(module.name, {
        "insert_link",
    })

    -- define the keybindings
    local neorg_callbacks = require("neorg.core.callbacks")
    neorg_callbacks.on_event("core.keybinds.events.enable_keybinds", function(_, keybnds)
        keybnds.map_event_to_mode("norg", {
            n = {
                { module.config.public.keymaps.insert_link, "core.integrations.roam.insert_link" },
            },
        }, { silent = true, noremap = true })
    end)
end
module.config.public = {
    keymaps = {
        select_prompt = "<C-n>",
        insert_link = "<leader>ni",
        find_note = "<leader>nf",
        capture_note = "<leader>nc",
        capture_index = "<leader>nci",
        capture_cancel = "<C-q>",
        capture_save = "<C-w>",
    },
    theme = "ivy",
}
module.config.private = {
    find_note = function(prompt, selection)
        local choice = nil
        if selection == nil and prompt == nil then
            return
        end
        if selection == nil then
            choice = module.required["core.dirman"].get_current_workspace()[2] .. "/" .. prompt .. ".norg"
        else
            choice = selection[1]
        end
        vim.cmd("e " .. choice)
        local buf = vim.api.nvim_get_current_buf()
        local metadata_present = module.required["core.esupports.metagen"].is_metadata_present(buf)
        if metadata_present then
            vim.cmd("Neorg update-metadata")
        else
            vim.cmd("Neorg inject-metadata")
        end
    end,
    capture_note = function(prompt, selection)
        if selection == nil and prompt == nil then
            return
        end
        local file_metadata = {}
        if selection == nil then
            file_metadata.title = prompt
        else
            file_metadata.title = selection.display
        end
        module.required["core.integrations.roam.capture"].capture_note(file_metadata)
    end,
    capture_link = function(prompt, file)
        if prompt == nil and file == nil then
            return
        end
        local link = ""
        if file == nil then
            link = "{:" .. prompt .. ":}[" .. prompt .. "]"
            module.required["core.integrations.roam.capture"].capture_link(
                module.required["core.dirman"].get_current_workspace()[2] .. "/" .. prompt .. ".norg",
                link
            )
        else
            local start_index = #module.required["core.dirman"].get_current_workspace()[2] + 2
            link = "{:" .. file[1]:sub(start_index, -6) .. ":}[" .. file[1]:sub(start_index, -6) .. "]"
            vim.api.nvim_put({ link }, "c", true, true)
        end
    end,
}

-- handle events.
module.on_event = function(event)
    local event_handlers = {
        ["core.integrations.roam.insert_link"] = module.public.insert_link,
    }
    if event.split_type[1] == "core.keybinds" then
        local handler = event_handlers[event.split_type[2]]
        if handler then
            handler()
        else
            error("No handler defined for " .. event.split_type[2])
        end
    end
end

-- subscribe to events
module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.integrations.roam.insert_link"] = true,
    },
}

module.private = {
    get_files = function()
        local dirman = module.required["core.dirman"]
        if dirman == nil then
            error("The neorgroam module requires core.dirman")
        end

        local curr_wksp = dirman.get_current_workspace()
        local files = dirman.get_norg_files(curr_wksp[1])
        return { curr_wksp, files }
    end,
}
module.public = {
    find_note = function()
        local wksp_files = module.private.get_files()
        local curr_wksp = wksp_files[1]
        local files = wksp_files[2]
        local title = "Find note - " .. module.config.public.keymaps.select_prompt .. " to create new note"
        local picker = utils.generate_picker(files, curr_wksp, title, module.config.private.find_note)
        if picker == nil then
            return
        end
        picker:find()
    end,
    capture_note = function()
        local wksp_files = module.private.get_files()
        local curr_wksp = wksp_files[1]
        local files = wksp_files[2]
        local title = "Capture note - " .. module.config.public.keymaps.select_prompt .. " to create new capture"
        local picker = utils.generate_picker(files, curr_wksp, title, module.config.private.capture_note)
        if picker == nil then
            return
        end
        picker:find()
    end,
    capture_index = function()
        local curr_wksp = module.required["core.dirman"].get_current_workspace()[2]
        module.required["core.integrations.roam.capture"].capture_note(curr_wksp .. "/index.norg")
    end,
    insert_link = function()
        local wksp_files = module.private.get_files()
        local curr_wksp = wksp_files[1]
        local files = wksp_files[2]
        local title = "Insert link - " .. module.config.public.keymaps.select_prompt .. " to create and insert"
        local picker = utils.generate_picker(files, curr_wksp, title, module.config.private.capture_link)
        picker:find()
    end,
    get_back_links = function() end,
    db_sync = function() end,
    db_sync_workspace = function(wksp) end,
}

vim.keymap.set("n", "<leader>hrr", ":lua require('dev').reload()<CR>")
return module
