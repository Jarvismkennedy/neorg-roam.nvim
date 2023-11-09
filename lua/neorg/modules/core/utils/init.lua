local M = {}
M.create_capture_window = function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    local width = vim.api.nvim_get_option("columns")
    local height = vim.api.nvim_get_option("lines")

    local win_height = math.ceil(height * 0.8 - 4)
    local win_width = math.ceil(width * 0.8)

    local row = math.ceil((height - win_height) / 2 - 1)
    local col = math.ceil((width - win_width) / 2)

    local keymaps = require("neorg.modules.core.integrations.roam.module").config.public.keymaps

    local opts = {
        relative = "editor",
        width = win_width,
        height = win_height,
        row = row,
        col = col,
        border = "rounded",
        title = "Cancel capture: " .. keymaps.capture_cancel .. ", Save capture: " .. keymaps.capture_save,
        title_pos = "center",
    }

    local win = vim.api.nvim_open_win(buf, true, opts)
    return { buf, win }
end

M.generate_capture_template_picker = function(templates, callback)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local conf = require("telescope.config").values
    local theme_name = require("neorg.modules.core.integrations.roam.module").config.public.theme
    local opts = require("telescope.themes")["get_" .. theme_name]({})
    return pickers.new(opts, {
        prompt_title = "Capture Template",
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                callback(selection.value)
            end)
            -- Maps for creating a new note
            return true
        end,
        sorter = conf.generic_sorter({}),
        finder = finders.new_table({
            results = templates,
            entry_maker = function(template)
                return {
                    value = template,
                    display = template.name,
                    ordinal = template.name,
                }
            end,
        }),
    })
end

M.generate_picker = function(files, curr_wksp, title, action)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local conf = require("telescope.config").values
    local theme_name = require("neorg.modules.core.integrations.roam.module").config.public.theme
    local opts = require("telescope.themes")["get_" .. theme_name]({})

    local start_index = #curr_wksp + 2
    local entries = {}
    for i, v in ipairs(files) do
        table.insert(entries, { v, v:sub(start_index, -6) })
    end
    return pickers.new(opts, {
        prompt_title = title,
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local current_picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
                local prompt = current_picker:_get_prompt()
                local selection = action_state.get_selected_entry()
                if selection ~= nil then
                    actions.close(prompt_bufnr)
                    action(prompt, selection)
                else
                    actions.close(prompt_bufnr)
                    action(prompt, nil)
                end
            end)
            -- Maps for creating a new note
            map(
                { "i", "n" },
                require("neorg.modules.core.integrations.roam.module").config.public.keymaps.select_prompt,
                function()
                    local current_picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
                    local prompt = current_picker:_get_prompt()
                    actions.close(prompt_bufnr)
                    if prompt == nil or prompt == "" then
                        error("Cant create new from an empty prompt.")
                    end
                    action(prompt, nil)
                end
            )
            return true
        end,
        previewer = conf.file_previewer({}),
        sorter = conf.file_sorter({}),
        finder = finders.new_table({
            results = entries,
            entry_maker = function(entry)
                return {
                    value = entry[1],
                    display = entry[2],
                    ordinal = entry[2],
                }
            end,
        }),
    })
end

return M
