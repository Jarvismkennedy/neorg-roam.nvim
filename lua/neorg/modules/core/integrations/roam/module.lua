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

    -- register keybinds
    local keybinds = module.required["core.keybinds"]
    keybinds.register_keybinds(module.name, { "find_note", "insert_link", "capture_cancel", "capture_save" })

    -- define the keybindings
    local neorg_callbacks = require("neorg.core.callbacks")
    neorg_callbacks.on_event("core.keybinds.events.enable_keybinds", function(_, keybinds)
        keybinds.map_event_to_mode("all", {
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
    end)

    -- set the keybind for pulling up the telescope find note
    vim.keymap.set("n", module.config.public.keymaps.find_note, module.public.find_note)
    vim.keymap.set("n", module.config.public.keymaps.capture_note, module.public.capture_note)
end
module.config.public = {
    keymaps = {
        select_prompt = "<C-n>",
        insert_link = "<leader>nri",
        find_note = "<leader>nrf",
        capture_note = "<leader>nrc",
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
    }
    if event.split_type[1] == "core.keybinds" then
        local handler = event_handlers[event.split_type[2]]
        if handler then
            handler()
        else
            error("No handler defined for " .. event.splut_type[2])
        end
    end
end

-- subscribe to events
module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.integrations.roam.insert_link"] = true, -- Subscribe to the event
        ["core.integrations.roam.capture_save"] = true,
        ["core.integrations.roam.capture_cancel"] = true,
    },
}

module.private = {
    capture_buffer = nil,
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
        local picker = utils.generate_picker(files, curr_wksp)
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
        local picker = utils.generate_picker(files, curr_wksp)
        local action = function(prompt, selection)
            local choice = nil
            local metadata = nil
            if selection == nil and prompt == nil then
                return
            end
            if selection == nil then
                choice = curr_wksp[2] .. "/" .. prompt .. ".norg"
                metadata = "Neorg inject-metadata"
            else
                choice = selection[1]
                metadata = "Neorg update-metadata"
            end
            local buf_win = utils.create_capture_window(module.config.public.keymaps)
            local buf = buf_win[1]
            module.required["core.mode"].set_mode("roam_capture")
            vim.api.nvim_buf_call(buf, function()
                -- edit the choice in the capture window, update/inject metadata, jump to bottom
                -- of file, and enter a new line.
                vim.cmd("e " .. choice)
                vim.cmd(metadata)
                vim.cmd("$")
                vim.cmd("normal o")
            end)
            module.private.capture_buffer = vim.api.nvim_win_get_buf(buf_win[2])
        end
        if picker == nil then
            return
        end
        picker(action):find()
    end,
    -- capture to workspace index.
    capture_save = function()
        if module.private.capture_buffer == nil then
            error("Capture buffer is nil")
        end
        module.required["core.mode"].set_previous_mode()
        vim.print(module.private)
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
        local picker = utils.generate_picker(files, curr_wksp)
        local action = function(prompt, file)
            if prompt == nil and file == nil then
                return
            end
            local link = ""
            if file == nil then
                error("need to implement capturing still")
                link = "{:" .. prompt .. ":}"
            else
                local start_index = #curr_wksp[2] + 2
                link = "{:" .. file[1]:sub(start_index, -6) .. ":}[" .. "GET TITLE HERE" .. "]"
            end
            vim.api.nvim_put({ link }, "c", true, true)
        end
        picker(action):find()
    end,
    get_back_links = function() end,
    db_sync = function() end,
    db_sync_workspace = function(wksp) end,
}

vim.keymap.set("n", "<leader>hrr", ":lua require('dev').reload()<CR>")
return module
