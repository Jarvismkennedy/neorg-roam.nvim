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
        keybinds.map_event_to_mode("roam_capture", {
            n = {
                { module.config.public.keymaps.capture_save, "core.integrations.roam.capture_save" },
                { module.config.public.keymaps.capture_cancel, "core.integrations.roam.capture_cancel" },
            },
            v = {
                { module.config.public.keymaps.capture_save, "core.integrations.roam.capture_save" },
                { module.config.public.keymaps.capture_cancel, "core.integrations.roam.capture_cancel" },
            },
            i = {
                { module.config.public.keymaps.capture_save, "core.integrations.roam.capture_save" },
                { module.config.public.keymaps.capture_cancel, "core.integrations.roam.capture_cancel" },
            },
        }, { silent = true, noremap = true })
        keybinds.map_event_to_mode("roam_capture_link", {
            n = {
                { module.config.public.keymaps.capture_save, "core.integrations.roam.capture_link_save" },
                { module.config.public.keymaps.capture_cancel, "core.integrations.roam.capture_link_cancel" },
            },
            v = {
                { module.config.public.keymaps.capture_save, "core.integrations.roam.capture_link_save" },
                { module.config.public.keymaps.capture_cancel, "core.integrations.roam.capture_link_cancel" },
            },
            i = {
                { module.config.public.keymaps.capture_save, "core.integrations.roam.capture_link_save" },
                { module.config.public.keymaps.capture_cancel, "core.integrations.roam.capture_link_cancel" },
            },
        }, { silent = true, noremap = true })

        -- add all the default keybinds back in. Theres got to be a better way to do this rather
        -- than copy pasta from neorg source code..............................
        --
        keybinds.map_event_to_mode("roam_capture", {
            n = {
                -- Marks the task under the cursor as "undone"
                -- ^mark Task as Undone
                { "<leader>" .. "tu", "core.qol.todo_items.todo.task_undone", opts = { desc = "Mark as Undone" } },
                -- Marks the task under the cursor as "pending"
                -- ^mark Task as Pending
                { "<leader>" .. "tp", "core.qol.todo_items.todo.task_pending", opts = { desc = "Mark as Pending" } },

                -- Marks the task under the cursor as "done"
                -- ^mark Task as Done
                { "<leader>" .. "td", "core.qol.todo_items.todo.task_done", opts = { desc = "Mark as Done" } },

                -- Marks the task under the cursor as "on_hold"
                -- ^mark Task as on Hold
                { "<leader>" .. "th", "core.qol.todo_items.todo.task_on_hold", opts = { desc = "Mark as On Hold" } },

                -- Marks the task under the cursor as "cancelled"
                -- ^mark Task as Cancelled
                {
                    "<leader>" .. "tc",
                    "core.qol.todo_items.todo.task_cancelled",
                    opts = { desc = "Mark as Cancelled" },
                },

                -- Marks the task under the cursor as "recurring"
                -- ^mark Task as Recurring
                {
                    "<leader>" .. "tr",
                    "core.qol.todo_items.todo.task_recurring",
                    opts = { desc = "Mark as Recurring" },
                },

                -- Marks the task under the cursor as "important"
                -- ^mark Task as Important
                {
                    "<leader>" .. "ti",
                    "core.qol.todo_items.todo.task_important",
                    opts = { desc = "Mark as Important" },
                },

                -- Marks the task under the cursor as "ambiguous"
                -- ^mark Task as ambiguous
                { "<leader>" .. "ta", "core.qol.todo_items.todo.task_ambiguous", opts = { desc = "Mark as Ambigous" } },

                -- Switches the task under the cursor between a select few states
                { "<C-Space>", "core.qol.todo_items.todo.task_cycle", opts = { desc = "Cycle Task" } },

                -- Creates a new .norg file to take notes in
                -- ^New Note
                { "<leader>" .. "nn", "core.dirman.new.note", opts = { desc = "Create New Note" } },

                -- Hop to the destination of the link under the cursor
                { "<CR>", "core.esupports.hop.hop-link", opts = { desc = "Jump to Link" } },
                { "gd", "core.esupports.hop.hop-link", opts = { desc = "Jump to Link" } },
                { "gf", "core.esupports.hop.hop-link", opts = { desc = "Jump to Link" } },
                { "gF", "core.esupports.hop.hop-link", opts = { desc = "Jump to Link" } },

                -- Same as `<CR>`, except opens the destination in a vertical split
                {
                    "<M-CR>",
                    "core.esupports.hop.hop-link",
                    "vsplit",
                    opts = { desc = "Jump to Link (Vertical Split)" },
                },

                { ">.", "core.promo.promote", opts = { desc = "Promote Object (Non-Recursively)" } },
                { "<,", "core.promo.demote", opts = { desc = "Demote Object (Non-Recursively)" } },

                { ">>", "core.promo.promote", "nested", opts = { desc = "Promote Object (Recursively)" } },
                { "<<", "core.promo.demote", "nested", opts = { desc = "Demote Object (Recursively)" } },

                { "<leader>" .. "lt", "core.pivot.toggle-list-type", opts = { desc = "Toggle (Un)ordered List" } },
                { "<leader>" .. "li", "core.pivot.invert-list-type", opts = { desc = "Invert (Un)ordered List" } },

                { "<leader>" .. "id", "core.tempus.insert-date", opts = { desc = "Insert Date" } },
            },

            i = {
                { "<C-t>", "core.promo.promote", opts = { desc = "Promote Object (Recursively)" } },
                { "<C-d>", "core.promo.demote", opts = { desc = "Demote Object (Recursively)" } },
                { "<M-CR>", "core.itero.next-iteration", "<CR>", opts = { desc = "Continue Object" } },
                { "<M-d>", "core.tempus.insert-date-insert-mode", opts = { desc = "Insert Date" } },
            },
        }, {
            silent = true,
            noremap = true,
        })
        keybinds.map_event_to_mode("roam_capture_link", {
            n = {
                -- Marks the task under the cursor as "undone"
                -- ^mark Task as Undone
                { "<leader>" .. "tu", "core.qol.todo_items.todo.task_undone", opts = { desc = "Mark as Undone" } },

                -- Marks the task under the cursor as "pending"
                -- ^mark Task as Pending
                { "<leader>" .. "tp", "core.qol.todo_items.todo.task_pending", opts = { desc = "Mark as Pending" } },

                -- Marks the task under the cursor as "done"
                -- ^mark Task as Done
                { "<leader>" .. "td", "core.qol.todo_items.todo.task_done", opts = { desc = "Mark as Done" } },

                -- Marks the task under the cursor as "on_hold"
                -- ^mark Task as on Hold
                { "<leader>" .. "th", "core.qol.todo_items.todo.task_on_hold", opts = { desc = "Mark as On Hold" } },

                -- Marks the task under the cursor as "cancelled"
                -- ^mark Task as Cancelled
                {
                    "<leader>" .. "tc",
                    "core.qol.todo_items.todo.task_cancelled",
                    opts = { desc = "Mark as Cancelled" },
                },

                -- Marks the task under the cursor as "recurring"
                -- ^mark Task as Recurring
                {
                    "<leader>" .. "tr",
                    "core.qol.todo_items.todo.task_recurring",
                    opts = { desc = "Mark as Recurring" },
                },

                -- Marks the task under the cursor as "important"
                -- ^mark Task as Important
                {
                    "<leader>" .. "ti",
                    "core.qol.todo_items.todo.task_important",
                    opts = { desc = "Mark as Important" },
                },

                -- Marks the task under the cursor as "ambiguous"
                -- ^mark Task as ambiguous
                { "<leader>" .. "ta", "core.qol.todo_items.todo.task_ambiguous", opts = { desc = "Mark as Ambigous" } },

                -- Switches the task under the cursor between a select few states
                { "<C-Space>", "core.qol.todo_items.todo.task_cycle", opts = { desc = "Cycle Task" } },

                -- Creates a new .norg file to take notes in
                -- ^New Note
                { "<leader>" .. "nn", "core.dirman.new.note", opts = { desc = "Create New Note" } },

                -- Hop to the destination of the link under the cursor
                { "<CR>", "core.esupports.hop.hop-link", opts = { desc = "Jump to Link" } },
                { "gd", "core.esupports.hop.hop-link", opts = { desc = "Jump to Link" } },
                { "gf", "core.esupports.hop.hop-link", opts = { desc = "Jump to Link" } },
                { "gF", "core.esupports.hop.hop-link", opts = { desc = "Jump to Link" } },

                -- Same as `<CR>`, except opens the destination in a vertical split
                {
                    "<M-CR>",
                    "core.esupports.hop.hop-link",
                    "vsplit",
                    opts = { desc = "Jump to Link (Vertical Split)" },
                },

                { ">.", "core.promo.promote", opts = { desc = "Promote Object (Non-Recursively)" } },
                { "<,", "core.promo.demote", opts = { desc = "Demote Object (Non-Recursively)" } },

                { ">>", "core.promo.promote", "nested", opts = { desc = "Promote Object (Recursively)" } },
                { "<<", "core.promo.demote", "nested", opts = { desc = "Demote Object (Recursively)" } },

                { "<leader>" .. "lt", "core.pivot.toggle-list-type", opts = { desc = "Toggle (Un)ordered List" } },
                { "<leader>" .. "li", "core.pivot.invert-list-type", opts = { desc = "Invert (Un)ordered List" } },

                { "<leader>" .. "id", "core.tempus.insert-date", opts = { desc = "Insert Date" } },
            },

            i = {
                { "<C-t>", "core.promo.promote", opts = { desc = "Promote Object (Recursively)" } },
                { "<C-d>", "core.promo.demote", opts = { desc = "Demote Object (Recursively)" } },
                { "<M-CR>", "core.itero.next-iteration", "<CR>", opts = { desc = "Continue Object" } },
                { "<M-d>", "core.tempus.insert-date-insert-mode", opts = { desc = "Insert Date" } },
            },
        }, {
            silent = true,
            noremap = true,
        })
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
        ["core.integrations.roam.capture_save"] = module.public.capture_save,
        ["core.integrations.roam.capture_cancel"] = module.public.capture_cancel,
        ["core.integrations.roam.capture_link_save"] = module.private.capture_link_save,
        ["core.integrations.roam.capture_link_cancel"] = module.private.capture_link_cancel,
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
        ["core.integrations.roam.capture_save"] = true,
        ["core.integrations.roam.capture_cancel"] = true,
        ["core.integrations.roam.capture_link_cancel"] = true,
        ["core.integrations.roam.capture_link_save"] = true,
    },
}

module.private = {
    capture_buffer = nil,
    capture_link_buffer = nil,
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
        end)
        vim.print(module.private.capture_buffer)
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
        if module.private.capture_buffer == nil then
            error("Capture buffer is nil")
        end
        module.required["core.mode"].set_previous_mode()
        vim.api.nvim_buf_call(module.private.capture_buffer, function()
            vim.cmd("w")
            vim.cmd("bd " .. module.private.capture_buffer)
        end)

        module.private.capture_buffer = nil
        vim.api.nvim_input("<esc>")
    end,
    capture_cancel = function()
        if module.private.capture_buffer == nil then
            error("Capture buffer is nil")
        end
        module.required["core.mode"].set_previous_mode()
        vim.api.nvim_buf_call(module.private.capture_buffer, function()
            vim.cmd("bd! " .. module.private.capture_buffer)
        end)
        module.private.capture_buffer = nil
        vim.api.nvim_input("<esc>")
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
