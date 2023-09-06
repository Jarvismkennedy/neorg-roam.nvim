local neorg = require("neorg.core")
local utils = require("neorg.modules.core.utils")

local module = neorg.modules.create("core.integrations.roam.capture")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.keybinds",
            "core.dirman",
            "core.esupports.metagen",
        },
    }
end
module.config.public = {
    keymaps = {},
    capture_templates = {
        {
            name = "default",
            file = "a/nested/dir/${datetimeiso}-${title}",
            narrowed = false,
            lines = { "" },
        },
    },
    substitution = {
        title = function(file_metadata)
            return file_metadata.title
        end,
        date = function(file_metadata)
            return os.date("%Y-%m-%d")
        end,
        datetimeiso = function(file_metadata)
            return os.date("!%Y-%m-%dT%TZ")
        end,
    },
}
module.private = {
    get_template_lines = function(template)
        vim.print(template)
        return { "", "testing get_template_lines" }
    end,
    substitute = function(line, file_metadata)
        return line:gsub("%${(%a+)}", function(s)
            local func = module.config.public.substitution[s]
            if func == nil then
                local input = vim.fn.input({ prompt = s .. ": " })
                return input
            end
            if type(func) == "function" then
                local ret = func(file_metadata)
                if type(ret) ~= "string" then
                    error("substitution function " .. s .. " must return a string but returned a " .. type(ret))
                end
                return ret
            else
                error("Type of " .. s .. " must be a function which returns a string")
            end
        end)
    end,
    register_buffer_for_capture_keymaps = function(buf)
        vim.keymap.set("n", module.config.public.keymaps.capture_save, module.public.capture_save, { buffer = buf })
        vim.keymap.set("n", module.config.public.keymaps.capture_cancel, module.public.capture_cancel, { buffer = buf })
        vim.keymap.set("v", module.config.public.keymaps.capture_save, module.public.capture_save, { buffer = buf })
        vim.keymap.set("v", module.config.public.keymaps.capture_cancel, module.public.capture_cancel, { buffer = buf })
        vim.keymap.set("i", module.config.public.keymaps.capture_save, module.public.capture_save, { buffer = buf })
        vim.keymap.set("i", module.config.public.keymaps.capture_cancel, module.public.capture_cancel, { buffer = buf })
    end,
    register_buffer_for_capture_link_keymaps = function(buf)
        vim.keymap.set(
            "n",
            module.config.public.keymaps.capture_save,
            module.public.capture_link_save,
            { buffer = buf }
        )
        vim.keymap.set(
            "n",
            module.config.public.keymaps.capture_cancel,
            module.public.capture_link_cancel,
            { buffer = buf }
        )
        vim.keymap.set(
            "v",
            module.config.public.keymaps.capture_save,
            module.public.capture_link_save,
            { buffer = buf }
        )
        vim.keymap.set(
            "v",
            module.config.public.keymaps.capture_cancel,
            module.public.capture_link_cancel,
            { buffer = buf }
        )
        vim.keymap.set(
            "i",
            module.config.public.keymaps.capture_save,
            module.public.capture_link_save,
            { buffer = buf }
        )
        vim.keymap.set(
            "i",
            module.config.public.keymaps.capture_cancel,
            module.public.capture_link_cancel,
            { buffer = buf }
        )
    end,
}
module.public = {
    set_keymaps = function(maps)
        module.config.public.keymaps = maps
    end,
    capture_note = function(file_metadata)
        local callback = function(template)
            local buf_win = utils.create_capture_window()
            local buf = buf_win[1]
            vim.api.nvim_buf_call(buf, function()
                -- edit the choice in the capture window, update/inject metadata, jump to bottom
                -- of file, and enter a new line.

                local file = module.required["core.dirman"].get_current_workspace()[2] .. "/"
                local file_exists = vim.fn.filereadable(file .. file_metadata.title .. ".norg") == 1
                if file_exists then
                    file = file .. file_metadata.title .. ".norg"
                else
                    file = file .. module.private.substitute(template.file, file_metadata) .. ".norg"
                end

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
                -- use treesitter instead.
                local row_of_meta_end = vim.fn.search("@end")
                vim.cmd(string.format(":call cursor(%d,0)", row_of_meta_end))
                vim.api.nvim_put(module.private.get_template_lines(template), "l", true, true)
            end)
            module.private.register_buffer_for_capture_keymaps(vim.api.nvim_win_get_buf(buf_win[2]))
        end
        if #module.config.public.capture_templates > 1 then
            utils.generate_capture_template_picker(module.config.public.capture_templates, callback):find()
        else
            callback(module.config.public.capture_templates[1])
        end
    end,
    capture_link = function(file, link)
        local buf = vim.api.nvim_get_current_buf()
        local win = vim.api.nvim_get_current_win()
        local pos = vim.api.nvim_win_get_cursor(win)
        -- save the buffer and cursor position to insert link on save
        module.private.capture_link_buffer = { id = buf, row = pos[1], col = pos[2], link = link }
        local buf_win = utils.create_capture_window()
        vim.api.nvim_buf_call(buf_win[1], function()
            vim.cmd("e " .. file)
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
        module.private.register_buffer_for_capture_link_keymaps(vim.api.nvim_win_get_buf(buf_win[2]))
    end,

    capture_save = function()
        vim.api.nvim_buf_call(0, function()
            vim.cmd("w")
            vim.cmd("bd")
        end)
        vim.api.nvim_input("<esc>")
    end,
    capture_cancel = function()
        vim.api.nvim_buf_call(0, function()
            vim.cmd("bd!")
        end)
        vim.api.nvim_input("<esc>")
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
return module
