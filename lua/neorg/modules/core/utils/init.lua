local M = {}

M.create_capture_window = function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.print({ buffer = buf })
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    local width = vim.api.nvim_get_option("columns")
    local height = vim.api.nvim_get_option("lines")

    local win_height = math.ceil(height * 0.8 - 4)
    local win_width = math.ceil(width * 0.8)

    local row = math.ceil((height - win_height) / 2 - 1)
    local col = math.ceil((width - win_width) / 2)

    local opts = {
        style = "minimal",
        relative = "editor",
        width = win_width,
        height = win_height,
        row = row,
        col = col,
        border = "rounded",
    }

    local win = vim.api.nvim_open_win(buf, true, opts)
    return { buf, win }
end
M.generate_picker = function(files, curr_wksp)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local sorter = require("telescope.sorters")
    local make_entry = require("telescope.make_entry")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    return function(action)
        opts = opts or {}
        return pickers.new(opts, {
            prompt_title = "colors",
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    local current_picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
                    local prompt = current_picker:_get_prompt()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    action(prompt, selection)
                end)
                -- Maps for creating a new note
                map(
                    { "i", "n" },
                    require("neorg.modules.core.integrations.roam.module").config.public.keymaps.select_prompt,
                    function()
                        local current_picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
                        local prompt = current_picker:_get_prompt()
                        actions.close(prompt_bufnr)
                        action(prompt, nil)
                    end
                )
                return true
            end,
            sorter = sorter.get_fzy_sorter(opts),
            finder = finders.new_table({
                results = files,
                entry_maker = make_entry.gen_from_file({ cwd = curr_wksp[2] }),
            }),
        })
    end
end

return M
