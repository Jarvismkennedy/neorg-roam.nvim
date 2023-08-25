local neorg = require("neorg.core")
local utils = require("neorg.modules.core.utils")
local module = neorg.modules.create("core.integrations.roam")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.keybinds",
            "core.dirman",
            "core.esupports.metagen",
            "core.mode",
        },
    }
end

module.load = function()
    -- register modes
    module.required["core.mode"].add_mode("roam_capture")
    module.required["core.mode"].add_mode("roam_capture_link")

    -- register keybinds
    local keybinds = module.required["core.keybinds"]
    keybinds.register_keybinds(module.name, {
        "find_note",
        "insert_link",
        "capture_cancel",
        "capture_save",
        "capture_link_save",
        "capture_link_cancel",
        "capture_index",
    })

    -- define the keybindings
    local neorg_callbacks = require("neorg.core.callbacks")
    neorg_callbacks.on_event("core.keybinds.events.enable_keybinds", function(_, keybinds)
        keybinds.map_event_to_mode("norg", {
            n = {
                { module.config.public.keymaps.insert_link, "core.integrations.roam.insert_link" },
            },
        }, { silent = true, noremap = true })
    end)

    -- set the keybind for pulling up the telescope find note
    vim.keymap.set("n", module.config.public.keymaps.find_note, module.public.find_note)
    vim.keymap.set("n", module.config.public.keymaps.capture_note, module.public.capture_note)
    vim.keymap.set("n", module.config.public.keymaps.capture_index, module.public.capture_index)
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
    register_buffer_for_keymaps = function(buf)
        vim.api.nvim_buf_set_keymap(buf, "n", module.config.public.keymaps.capture_note, module.public.capture_save)
    end,
    get_files = function()
        local dirman = module.required["core.dirman"]
        if dirman == nil then
            error("The neorgroam module requires core.dirman")
        end

        local curr_wksp = dirman.get_current_workspace()
        local files = dirman.get_norg_files(curr_wksp[1])
        return { curr_wksp, files }
    end,
    capture_note = function(file)
        local buf_win = utils.create_capture_window()
        local buf = buf_win[1]
        module.required["core.mode"].set_mode("roam_capture")

        vim.api.nvim_buf_call(buf, function()
            -- edit the choice in the capture window, update/inject metadata, jump to bottom
            -- of file, and enter a new line.
            vim.cmd("e " .. file)
            module.private.capture_buffer = vim.api.nvim_win_get_buf(buf_win[2])
            -- put cursor at the end of metadata.
            local metadata_present =
                module.required["core.esupports.metagen"].is_metadata_present(module.private.capture_buffer)

            if metadata_present then
                vim.cmd("Neorg update-metadata")
            else
                vim.cmd("Neorg inject-metadata")
            end
            -- search for the end of the metadata tag.
            local row_of_meta_end = vim.fn.search("@end")
            vim.cmd(string.format(":call cursor(%d,0)", row_of_meta_end))
            vim.cmd(":normal o")
            vim.cmd(":normal o")
        end)
        vim.api.nvim_win_set_var(buf_win[2], "capture_window", true)
        vim.api.nvim_buf_set_keymap()
    end,
    capture_link = function(file, link)
        local buf = vim.api.nvim_get_current_buf()
        local win = vim.api.nvim_get_current_win()
        local pos = vim.api.nvim_win_get_cursor(win)
        -- save the buffer and cursor position to insert link on save
        module.private.capture_link_buffer = { id = buf, row = pos[1], col = pos[2], link = link }
        local buf_win = utils.create_capture_window()
        local link_buf = buf_win[1]
        module.required["core.mode"].set_mode("roam_capture_link")
        vim.api.nvim_buf_call(buf, function()
            -- edit the choice in the capture window, update/inject metadata, jump to bottom
            -- of file, and enter a new line.
            vim.cmd("e " .. file)
            module.private.capture_buffer = vim.api.nvim_win_get_buf(buf_win[2])
            -- put cursor at the end of metadata.
            local metadata_present =
                module.required["core.esupports.metagen"].is_metadata_present(module.private.capture_buffer)

            if metadata_present then
                vim.cmd("Neorg update-metadata")
            else
                vim.cmd("Neorg inject-metadata")
            end
            -- search for the end of the metadata tag.
            local row_of_meta_end = vim.fn.search("@end")
            vim.cmd(string.format(":call cursor(%d,0)", row_of_meta_end))
            vim.cmd(":normal o")
        end)
        module.private.capture_buffer = vim.api.nvim_win_get_buf(buf_win[2])
    end,
    capture_link_save = function()
        module.public.capture_save()
        local capture_link = module.private.capture_link_buffer
        if capture_link == nil then
            error("Failed to insert link properly: capture_link_buffer is nil")
        end
        vim.api.nvim_set_current_buf(capture_link.id)
        vim.cmd(string.format(":call cursor(%d,%d)", capture_link.row, capture_link.col))
        vim.api.nvim_put({ capture_link.link }, "c", true, true)
    end,
    capture_link_cancel = function()
        module.private.capture_link_buffer = nil
        module.public.capture_cancel()
    end,
}
module.public = {
    find_note = function()
        local wksp_files = module.private.get_files()
        local curr_wksp = wksp_files[1]
        local files = wksp_files[2]
        local title = "Find note - " .. module.config.public.keymaps.select_prompt .. " to create new note"
        local picker = utils.generate_picker(files, curr_wksp, title)
        local action = function(prompt, selection)
            local choice = nil
            if selection == nil and prompt == nil then
                return
            end
            if selection == nil then
                choice = curr_wksp[2] .. "/" .. prompt .. ".norg"
                vim.cmd("e " .. choice)
                vim.cmd("Neorg inject-metadata")
            else
                choice = selection[1]
                vim.cmd("e " .. choice)
                vim.cmd("Neorg update-metadata")
            end
        end
        if picker == nil then
            return
        end
        picker(action):find()
    end,

    -- captures
    -- select a note to capture to.
    capture_note = function()
        local wksp_files = module.private.get_files()
        local curr_wksp = wksp_files[1]
        local files = wksp_files[2]
        local title = "Capture note - " .. module.config.public.keymaps.select_prompt .. " to create new capture"
        local picker = utils.generate_picker(files, curr_wksp, title)
        local action = function(prompt, selection)
            local choice = nil
            local metadata = nil
            if selection == nil and prompt == nil then
                return
            end
            if selection == nil then
                choice = curr_wksp[2] .. "/" .. prompt .. ".norg"
            else
                choice = selection[1]
            end
            module.private.capture_note(choice)
        end
        if picker == nil then
            return
        end
        picker(action):find()
    end,
    capture_index = function()
        local curr_wksp = module.required["core.dirman"].get_current_workspace()[2]
        module.private.capture_note(curr_wksp .. "/index.norg")
    end,
    -- capture to workspace index.
    capture_save = function()
        if vim.api.nvim_win_get_var(0, "capture_window") then
            vim.api.nvim_buf_call(0, function()
                vim.cmd("w")
                vim.cmd("bd")
            end)
            vim.api.nvim_input("<esc>")
        end
    end,
    capture_cancel = function()
        if vim.api.nvim_win_get_var(0, "capture_window") then
            vim.api.nvim_buf_call(0, function()
                vim.cmd("bd!")
            end)
            vim.api.nvim_input("<esc>")
        end
    end,
    --

    insert_link = function()
        local wksp_files = module.private.get_files()
        local curr_wksp = wksp_files[1]
        local files = wksp_files[2]
        local title = "Insert link - " .. module.config.public.keymaps.select_prompt .. " to create and insert"
        local picker = utils.generate_picker(files, curr_wksp, title)
        local action = function(prompt, file)
            if prompt == nil and file == nil then
                return
            end
            local link = ""
            if file == nil then
                link = "{:" .. prompt .. ":}[" .. prompt .. "]"
                module.private.capture_link(curr_wksp[2] .. "/" .. prompt .. ".norg", link)
            else
                local start_index = #curr_wksp[2] + 2
                link = "{:" .. file[1]:sub(start_index, -6) .. ":}[" .. file[1]:sub(start_index, -6) .. "]"
                vim.api.nvim_put({ link }, "c", true, true)
            end
        end
        picker(action):find()
    end,
    get_back_links = function() end,
    db_sync = function() end,
    db_sync_workspace = function(wksp) end,
}

vim.keymap.set("n", "<leader>hrr", ":lua require('dev').reload()<CR>")
return module
