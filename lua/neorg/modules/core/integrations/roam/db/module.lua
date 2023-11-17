local sqlite = require 'sqlite'
local neorg = require 'neorg.core'
local db = neorg.modules.create 'core.integrations.roam.db'

-- Hacky workaround because sqlite.lua doesn't escape everything correctly, so it passes strings
-- with () as functions
local escape = function(content)
    return string.format("__ESCAPED__'%s'", content)
end
local unescape = function(content)
    return content:gsub("^__ESCAPED__'(.*)'$", '%1')
end
local link_exists = function(from, to, t)
    for _, value in ipairs(t) do
        if value.source == from and value.target == to then
            return true
        end
    end
    return false
end
local process_note = function(note_tbl, fn)
    for key, val in pairs(note_tbl) do
        if key ~= 'id' and key ~= 'workspace' then
            note_tbl[key] = fn(val)
        end
    end
    return note_tbl
end
local function process_notes_for_db_sync(tbl)
    local t = {}
    for k, v in pairs(tbl) do
        table.insert(t, process_note(v, escape))
    end
    return t
end
local function starts_with(str, start)
    return str:sub(1, #start) == start
end
local function generate_links_entries(links, notes_entries)
    local entries = {}
    for _, link in ipairs(links) do
        local from_note = notes_entries[link.from]
        local to_note = notes_entries[link.to]
        if from_note == nil or to_note == nil or link_exists(from_note.id, to_note.id, entries) then
            goto continue
        end
        table.insert(entries, { source = from_note.id, target = to_note.id })
        ::continue::
    end
    return entries
end
local function get_or_generate_metadata(bufnr, force)
    vim.api.nvim_buf_call(bufnr, vim.cmd.edit)
    local metadata = db.required['core.integrations.roam.meta'].get_document_metadata(bufnr)
    if metadata == nil or metadata.id == nil or force then
        if metadata ~= nil then
            setmetatable(metadata, { __is_obj = true })
        end
        metadata = db.required['core.integrations.roam.meta'].inject_metadata(bufnr, true)
        vim.api.nvim_buf_call(bufnr, function()
            vim.cmd [[silent write]]
        end)
    end
    return metadata
end
db.setup = function()
    db.private.init()
    return {
        success = true,
        requires = {
            'core.dirman',
            'core.dirman.utils',
            'core.integrations.roam',
            'core.integrations.roam.treesitter',
            'core.integrations.roam.meta',
        },
    }
end
db.config.private = {
    db_path = vim.fn.stdpath 'data' .. '/roam.db',
}
db.private = {
    init = function()
        local notes = sqlite.tbl('notes', {
            id = { type = 'text', primary = true, required = true },
            path = { type = 'text', required = true, unique = true },
            workspace = { type = 'text', required = true },
            title = { type = 'text', required = true },
        })
        local links = sqlite.tbl('links', {
            id = true,
            source = {
                reference = 'notes.id',
                required = true,
                on_delete = 'cascade',
                on_update = 'cascade',
            },
            target = {
                reference = 'notes.id',
                required = true,
                on_delete = 'cascade',
                on_update = 'cascade',
            },
        })
        db.sql = sqlite {
            uri = db.config.private.db_path,
            notes = notes,
            links = links,
        }
    end,
    clean_db_file = function()
        -- first close all open neorg buffers
        local ok, _ = pcall(vim.cmd, 'Neorg return')
        if not ok then
            vim.notify(
                'Neorg-roam db_sync error: failed to run Neorg return. db_sync cannot run with open neorg buffers.',
                vim.log.levels.ERROR
            )
            return false
        end
        ok, _ = pcall(os.remove, db.config.private.db_path)
        if not ok then
            vim.notify(
                'Neorg-roam db_sync error: Failed to remove db file at ' .. db.config.private.db_path,
                vim.log.levels.ERROR
            )
            return false
        end
        ok, _ = pcall(db.private.init)
        if not ok then
            vim.notify(
                'Neorg-roam db_sync error: Failed to initialize db file at ' .. db.config.private.db_path,
                vim.log.levels.ERROR
            )
            return false
        end
        vim.notify '[neorg-roam] db file cleaned'
        return true
    end,
    clean_wksp = function(wksp)
        local ids = {}
        db.sql:with_open(function()
            local r = db.sql:eval('select id from notes where workspace = ?', wksp)
            for _, value in ipairs(r) do
                table.insert(ids, value.id)
            end
        end)
        db.sql.notes:remove { id = ids }
        db.sql.links:remove { source = ids }
    end,
}
db.public = {
    sync = function()
        local ok = db.private.clean_db_file()
        if not ok then
            return nil
        end
        -- start with roam workspace, add support for other workspaces later.
        -- p
        local wkspaces = db.required['core.integrations.roam'].get_workspaces()
        local notes_entries = {}
        local links = {}
        for _, wksp_name in ipairs(wkspaces) do
            local wksp = db.required['core.dirman'].get_workspace(wksp_name)
            local wksp_files = db.required['core.dirman'].get_norg_files(wksp_name)
            for _, file in ipairs(wksp_files) do
                local bufnr = vim.api.nvim_create_buf(true, false)
                vim.api.nvim_buf_set_name(bufnr, file)
                local metadata = get_or_generate_metadata(bufnr, true)
                notes_entries[file] = { path = file, id = metadata.id, workspace = wksp_name, title = metadata.title }
                local nodes = db.required['core.integrations.roam.treesitter'].get_norg_links(bufnr)
                vim.api.nvim_buf_delete(bufnr, {})
                for _, node in ipairs(nodes) do
                    local expand = ''
                    if starts_with(node, '$') then
                        expand = db.required['core.dirman.utils'].expand_path(node)
                    else
                        expand = wksp .. '/' .. node .. '.norg'
                    end
                    table.insert(links, { from = file, to = expand })
                end
            end
        end
        local links_entries = generate_links_entries(links, notes_entries)
        if next(notes_entries) then
            db.sql.notes:insert(process_notes_for_db_sync(notes_entries))
        end
        if #links_entries > 0 then
            db.sql.links:insert(links_entries)
        end

        vim.notify('Neorg-roam: synced db file.', vim.log.levels.INFO)
    end,

    sync_wksp = function(wksp_name)
        local notes_entries = {}
        local links = {}
        db.private.clean_wksp(wksp_name)
        local wksp = db.required['core.dirman'].get_workspace(wksp_name)
        local wksp_files = db.required['core.dirman'].get_norg_files(wksp_name)
        for _, file in ipairs(wksp_files) do
            local bufnr = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_name(bufnr, file)
            local metadata = get_or_generate_metadata(bufnr)
            notes_entries[file] = { path = file, id = metadata.id, workspace = wksp_name, title = metadata.title }
            local nodes = db.required['core.integrations.roam.treesitter'].get_norg_links(bufnr)
            vim.api.nvim_buf_delete(bufnr, {})
            for _, node in ipairs(nodes) do
                local expand = ''
                if starts_with(node, '$') then
                    expand = db.required['core.dirman.utils'].expand_path(node)
                else
                    expand = wksp .. '/' .. node .. '.norg'
                end
                table.insert(links, { from = file, to = expand })
            end
        end
        local links_entries = generate_links_entries(links, notes_entries)
        if next(notes_entries) then
            db.sql.notes:insert(process_notes_for_db_sync(notes_entries))
        end
        if #links_entries > 0 then
            db.sql.links:insert(links_entries)
        end
        vim.notify('[neorg-roam] synced workspace ' .. wksp_name .. '.', vim.log.levels.INFO)
    end,
    sync_file = function(bufnr)
        local metadata = get_or_generate_metadata(bufnr)
        local note = db.sql.notes:where { id = metadata.id }

        -- the solution to this is to list the roam workspace names as part of the config, then do
        -- an autocommand on norg files in the roam workspace to call sync_file.
        vim.print(note)
        -- local links = {}
        --           local nodes = db.required['core.integrations.roam.treesitter'].get_norg_links(bufnr)
        --           for _, node in ipairs(nodes) do
        --               local expand = ''
        --               if starts_with(node, '$') then
        --                   expand = db.required['core.dirman.utils'].expand_path(node)
        --               else
        --                   expand = wksp .. '/' .. node .. '.norg'
        --               end
        --               table.insert(links, { from = file, to = expand })
        --           end
    end,

    get_notes = function(wksp)
        -- should you even bother doing anything here or just use dirman?
    end,

    get_backlinks_from_id = function(id)
        local backlinks = {}
        db.sql:with_open(function()
            local r = db.sql:eval(
                [[
					select path, title
					from links join notes
					on links.source = notes.id
					where links.target = ?
				]],
                id
            )
            if r == true or r == false then
                r = {}
            else
                for _, value in ipairs(r) do
                    table.insert(backlinks, { path = unescape(value.path), title = unescape(value.title) })
                end
            end
        end)
        return backlinks
    end,
    get_backlinks = function(bufnr)
        local id = db.required['core.integrations.roam.treesitter'].get_document_metadata(bufnr).id
        if id == nil then
            error 'Norg document does not have an id. Please run db_sync.'
        end
        return db.public.get_backlinks_from_id(id)
    end,

    insert_note = function(note_data) end,

    insert_link = function(link_data) end,
}

return db
