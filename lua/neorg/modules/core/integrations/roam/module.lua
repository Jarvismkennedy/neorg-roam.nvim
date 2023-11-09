local neorg = require 'neorg.core'
local utils = require 'neorg.modules.core.utils'
local module = neorg.modules.create 'core.integrations.roam'

module.config = {}
module.setup = function()
    return {
        success = true,
        requires = {
            'core.keybinds',
            'core.dirman',
            'core.integrations.roam.meta',
            'core.integrations.roam.capture',
            'core.integrations.roam.db',
        },
    }
end
module.neorg_post_load = function()
    -- set the keybind for pulling up telescope
    vim.keymap.set('n', module.config.public.keymaps.find_note, module.public.find_note)
    vim.keymap.set('n', module.config.public.keymaps.capture_note, module.public.capture_note)
    vim.keymap.set('n', module.config.public.keymaps.capture_index, module.public.capture_index)
    vim.keymap.set('n', module.config.public.keymaps.db_sync, module.public.db_sync)
    vim.keymap.set('n', module.config.public.keymaps.db_sync_wksp, module.public.db_sync_wksp)
end
module.load = function()
    -- pass config to capture module.
    module.required['core.integrations.roam.capture'].set_config(module.config.public)

    -- register keybinds
    local keybinds = module.required['core.keybinds']
    keybinds.register_keybinds(module.name, {
        'insert_link',
        'get_backlinks',
    })

    -- define the keybindings
    local neorg_callbacks = require 'neorg.core.callbacks'
    neorg_callbacks.on_event('core.keybinds.events.enable_keybinds', function(_, keybnds)
        keybnds.map_event_to_mode('norg', {
            n = {
                { module.config.public.keymaps.insert_link, 'core.integrations.roam.insert_link' },
                { module.config.public.keymaps.get_backlinks, 'core.integrations.roam.get_backlinks' },
            },
        }, { silent = true, noremap = true })
    end)
    if module.config.public.workspaces == nil then
        error '[neorg-roam] Must include roam workspaces in neorg roam config.'
    end
    -- keep track of which workspaces are roam workspaces.
    module.config.private.wrksps = {}
    for i, v in ipairs(module.config.public.workspaces) do
        if type(v) ~= 'string' then
            return error('[neorg-roam] Invalid entry in workspaces config at index: ' .. i)
        end
        local wksp = module.required['dirman'].get_workspace(v)
        if wksp == nil then
            return error '[neorg-roam] Workspaces must be defined in the core.dirman module as well as the neorg-roam module'
        end
        table.insert(module.config.private.wrksps, wksp)
    end
    module.config.private.curr_wrksp = module.config.private.wrksps[1]
end
module.config.public = {
    keymaps = {
        select_prompt = '<C-n>',
        get_backlinks = '<leader>nb',
        insert_link = '<leader>ni',
        find_note = '<leader>nf',
        capture_note = '<leader>nc',
        capture_index = '<leader>nci',
        capture_cancel = '<C-q>',
        capture_save = '<C-w>',
        db_sync = '<leader>nsd',
        db_sync_wksp = '<leader>nsw',
    },
    capture_templates = {
        {
            name = 'default',
            file = '${title}',
            narrowed = false,
            lines = { '' },
        },
    },
    substitutions = {
        title = function(file_metadata)
            return file_metadata.title
        end,
        date = function(file_metadata)
            return os.date '%Y-%m-%d'
        end,
    },
    theme = 'ivy',
    workspaces = nil,
}
module.config.private = {
    find_note = function(prompt, selection)
        local choice = nil
        if selection == nil and prompt == nil then
            return
        end
        if selection == nil then
            choice = prompt
        else
            choice = selection.display
        end
        local file_path = module.required['core.dirman'].get_current_workspace()[2] .. '/' .. choice .. '.norg'
        if vim.fn.filereadable(file_path) == 0 then
            module.required['core.integrations.roam.capture'].capture_note(choice)
        else
            vim.cmd('e ' .. file_path)
            local buf = vim.api.nvim_get_current_buf()
            module.required['core.integrations.roam.meta'].inject_metadata(buf)
        end
    end,
    capture_note = function(prompt, selection)
        if selection == nil and prompt == nil then
            return
        end
        local title = nil
        if selection == nil then
            title = prompt
        else
            title = selection.display
        end
        module.required['core.integrations.roam.capture'].capture_note(title)
    end,
    insert_link = function(prompt, selection)
        local file = nil
        if selection ~= nil then
            file = selection.display
        end
        if prompt == nil and file == nil then
            return
        end
        if file == nil then
            local title = prompt
            module.required['core.integrations.roam.capture'].capture_link(title)
        else
            local link = '{:' .. file .. ':}[' .. file .. ']'
            vim.api.nvim_put({ link }, 'c', true, true)
        end
    end,
    curr_wrksp = nil,
}

-- handle events.
module.on_event = function(event)
    local event_handlers = {
        ['core.integrations.roam.insert_link'] = module.public.insert_link,
        ['core.integrations.roam.get_backlinks'] = module.public.get_backlinks,
    }
    if event.split_type[1] == 'core.keybinds' then
        local handler = event_handlers[event.split_type[2]]
        if handler then
            handler()
        else
            error('No handler defined for ' .. event.split_type[2])
        end
    end
end

-- subscribe to events
module.events.subscribed = {
    ['core.keybinds'] = {
        ['core.integrations.roam.insert_link'] = true,
        ['core.integrations.roam.get_backlinks'] = true,
    },
}

module.private = {
    get_files = function()
        local dirman = module.required['core.dirman']
        if dirman == nil then
            error 'The neorgroam module requires core.dirman'
        end

        local curr_wksp = module.config.private.curr_wrksp
        if curr_wksp == nil then
            error '[neorg-roam] current workspace is nil'
        end
        local files = dirman.get_norg_files(curr_wksp[1])
        return { curr_wksp, files }
    end,
}
module.public = {
    get_workspaces = function()
        return module.config.private.wrksps
    end,
    get_current_workspace = function()
        return module.config.private.curr_wrksp
    end,
    find_note = function()
        local wksp_files = module.private.get_files()
        local curr_wksp = wksp_files[1]
        local files = wksp_files[2]
        local title = 'Find note - ' .. module.config.public.keymaps.select_prompt .. ' to select new note'
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
        local title = 'Capture note - ' .. module.config.public.keymaps.select_prompt .. ' to select new capture'
        local picker = utils.generate_picker(files, curr_wksp, title, module.config.private.capture_note)
        if picker == nil then
            return
        end
        picker:find()
    end,
    capture_to_file = function(file_path)
        error '[neorg-roam] capture to file by file name is not yet implimented'
    end,
    insert_link = function()
        local wksp_files = module.private.get_files()
        local curr_wksp = wksp_files[1]
        local files = wksp_files[2]
        local title = 'Insert link - ' .. module.config.public.keymaps.select_prompt .. ' to create and insert'
        local picker = utils.generate_picker(files, curr_wksp, title, module.config.private.insert_link)
        picker:find()
    end,
    get_backlinks = function()
        vim.print(module.required['core.integrations.roam.db'].get_backlinks(0))
    end,
    db_sync = function()
        module.required['core.integrations.roam.db'].sync()
    end,
    db_sync_wksp = function()
        local wkspaces = module.required['core.dirman'].get_workspace_names()
        local wksp = vim.ui.select(wkspaces, { prompt = 'Sync Workspace: ' }, function(choice)
            module.required['core.integrations.roam.db'].sync_wksp(choice)
        end)
    end,
}

return module
