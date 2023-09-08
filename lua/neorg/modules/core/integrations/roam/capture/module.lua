local neorg = require("neorg.core")
local utils = require("neorg.modules.core.utils")
local neorg_utils = require("neorg.core.utils")

local module = neorg.modules.create("core.integrations.roam.capture")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.keybinds",
            "core.dirman",
            "core.esupports.metagen",
            "core.integrations.treesitter",
        },
    }
end
module.config.private = {
    metadata_query = [[
	(ranged_verbatim_tag
		name: (tag_name) @name (#eq? @name "document.meta")
	) @meta_data
	]],
    temporary_substitutions = {},
}
module.config.public = {}

module.private = {
    update_metadata_title = function(title, buf)
        buf = buf or 0
        -- this is coppied from metagen modules update_metadata
        -- It would be cool if they had an api to update instead of needing to do this.
        local present = module.required["core.esupports.metagen"].is_metadata_present(buf)

        if not present then
            return
        end

        -- Extract the root node of the norg_meta language
        -- This process should be abstracted into a core.integrations.treesitter
        -- function.
        local languagetree = vim.treesitter.get_parser(buf, "norg")

        if not languagetree then
            return
        end

        local meta_root = nil

        languagetree:for_each_child(function(tree)
            if tree:lang() ~= "norg_meta" or meta_root then
                return
            end

            local meta_tree = tree:parse()[1]

            if not meta_tree then
                return
            end

            meta_root = meta_tree:root()
        end)

        if not meta_root then
            return
        end

        local query = neorg_utils.ts_parse_query(
            "norg_meta",
            [[
            (pair
                (key) @_key
                (#eq? @_key "title")
                (value) @title)
        ]]
        )

        for id, node in query:iter_captures(meta_root, buf) do
            local capture = query.captures[id]
            if capture == "title" then
                local curr_title = module.required["core.integrations.treesitter"].get_node_text(node)

                if title ~= curr_title then
                    local range = module.required["core.integrations.treesitter"].get_node_range(node)
                    vim.api.nvim_buf_set_text(
                        buf,
                        range.row_start,
                        range.column_start,
                        range.row_end,
                        range.column_end,
                        { title }
                    )
                end
            end
        end
    end,

    get_meta_range = function(buf)
        buf = buf or 0
        --{start row, start col, end row, end col }
        local range = nil
        module.required["core.integrations.treesitter"].execute_query(
            module.config.private.metadata_query,
            function(query, id, node, metadata)
                if query.captures[id] == "meta_data" then
                    range = { node:range() }
                    return true
                end
            end,
            0,
            0,
            -1
        )
        return range
    end,
    get_template_lines = function(template, file_metadata)
        local lines = {}
        for i, line in ipairs(template.lines) do
            local sub = module.private.substitute(line, file_metadata)
            table.insert(lines, sub)
        end
        return lines
    end,
    substitute = function(line, file_metadata)
        return line:gsub("%${(%w+)}", function(s)
            local func = module.config.public.substitutions[s]
            if func == nil then
                if module.config.private.temporary_substitutions[s] ~= nil then
                    return module.config.private.temporary_substitutions[s]
                end

                local input = vim.fn.input({ prompt = s .. ": " })
                module.config.private.temporary_substitutions[s] = input
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
    set_config = function(config)
        module.config.public = config
    end,
    capture_note = function(title)
        local callback = function(template)
            local buf_win = utils.create_capture_window()
            local buf = buf_win[1]
            vim.api.nvim_buf_call(buf, function()
                -- edit the choice in the capture window, update/inject metadata, jump to bottom
                -- of file, and enter a new line.

                local file = module.required["core.dirman"].get_current_workspace()[2] .. "/"
                local file_exists = vim.fn.filereadable(file .. title .. ".norg") == 1
                if file_exists then
                    file = file .. title .. ".norg"
                else
                    file = file .. module.private.substitute(template.file or "${title}", { title = title }) .. ".norg"
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

                local end_row = module.private.get_meta_range(0)[3] + 2
                if end_row == nil then
                    error("ERROR WITH TREESITTER METADATA QUERY")
                end
                vim.cmd(string.format(":call cursor(%d,0)", end_row))
                local metadata = module.required["core.integrations.treesitter"].get_document_metadata()
                metadata.title = title
                local lines = module.private.get_template_lines(template, metadata)

                -- if the file doesn't already exist, update the title
                if not file_exists and template.title ~= nil then
                    -- replace the metadata title with the title param instead of using file name.
                    local meta_title = module.private.substitute(template.title, { title = title })
                    module.private.update_metadata_title(meta_title, module.private.capture_buffer)
                end
                vim.api.nvim_put(lines, "c", false, true)
                vim.cmd("normal a")
                module.config.private.temporary_substitutions = {}
            end)
            module.private.register_buffer_for_capture_keymaps(vim.api.nvim_win_get_buf(buf_win[2]))
        end
        if #module.config.public.capture_templates > 1 then
            utils.generate_capture_template_picker(module.config.public.capture_templates, callback):find()
        else
            callback(module.config.public.capture_templates[1])
        end
    end,
    capture_link = function(title)
        local buf = vim.api.nvim_get_current_buf()
        local win = vim.api.nvim_get_current_win()
        local pos = vim.api.nvim_win_get_cursor(win)
        -- save the buffer and cursor position to insert link on save
        module.private.capture_link_buffer = { id = buf, row = pos[1], col = pos[2] }
        local callback = function(template)
            local buf_win = utils.create_capture_window()
            vim.api.nvim_buf_call(buf_win[1], function()
                local file = module.required["core.dirman"].get_current_workspace()[2] .. "/"
                local file_exists = vim.fn.filereadable(file .. title .. ".norg") == 1
                local norg_link = ""
                if file_exists then
                    file = file .. title .. ".norg"
                    norg_link = "{:" .. title .. ":}"
                else
                    local substituted_file_name =
                        module.private.substitute(template.file or "${title}", { title = title })
                    norg_link = "{:" .. substituted_file_name .. ":}"
                    file = file .. substituted_file_name .. ".norg"
                end
                local link = norg_link .. "[" .. title .. "]"
                module.private.capture_link_buffer.link = link
                vim.cmd("e " .. file)
                -- put cursor at the end of metadata.
                local metadata_present =
                    module.required["core.esupports.metagen"].is_metadata_present(module.private.capture_buffer)
                if metadata_present then
                    vim.cmd("Neorg update-metadata")
                else
                    vim.cmd("Neorg inject-metadata")
                end

                local end_row = module.private.get_meta_range(0)[3] + 2
                if end_row == nil then
                    error("ERROR WITH TREESITTER METADATA QUERY")
                end
                vim.cmd(string.format(":call cursor(%d,0)", end_row))
                local metadata = module.required["core.integrations.treesitter"].get_document_metadata()
                metadata.title = title
                local lines = module.private.get_template_lines(template, metadata)

                -- if the file doesn't already exist, update the title
                if not file_exists and template.title ~= nil then
                    -- replace the metadata title with the title param instead of using file name.
                    local meta_title = module.private.substitute(template.title, { title = title })
                    module.private.update_metadata_title(meta_title, module.private.capture_buffer)
                end
                vim.api.nvim_put(lines, "c", false, true)
                vim.cmd("normal a")

                module.config.private.temporary_substitutions = {}
            end)
            module.private.register_buffer_for_capture_link_keymaps(vim.api.nvim_win_get_buf(buf_win[2]))
        end
        if #module.config.public.capture_templates > 1 then
            utils.generate_capture_template_picker(module.config.public.capture_templates, callback):find()
        else
            callback(module.config.public.capture_templates[1])
        end
    end,

    capture_save = function()
        vim.api.nvim_buf_call(0, function()
            vim.cmd(':call mkdir(expand("%:p:h"), "p")')
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
