local sqlite = require("sqlite")
local neorg = require("neorg.core")
local db = neorg.modules.create("core.integrations.roam.db")
-- Hacky workaround because sqlite.lua doesn't escape everything correctly, so it passes strings
-- with () as functions
local escape = function(content)
	return string.format("__ESCAPED__'%s'", content)
end
local unescape = function(content)
	return content:gsub("^__ESCAPED__'(.*)'$", "%1")
end
local link_exists = function(from, to, t)
	for index, value in ipairs(t) do
		if value.source == from and value.target == to then
			return true
		end
	end
	return false
end
local process_note = function(note_tbl, fn)
	for key, val in pairs(note_tbl) do
		if key ~= "id" and key ~= "workspace" then
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
	for i, link in ipairs(links) do
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
local function get_or_generate_metadata(file, bufnr)
	vim.api.nvim_buf_set_name(bufnr, file)
	vim.api.nvim_buf_call(bufnr, vim.cmd.edit)
	local metadata = db.required["core.integrations.roam.meta"].get_document_metadata(bufnr)
	if metadata == nil or metadata.id == nil then
		metadata = db.required["core.integrations.roam.meta"].inject_metadata(bufnr, true, nil)
		vim.api.nvim_buf_call(bufnr, function()
			vim.cmd([[write]])
		end)
	end
	return metadata
end
db.setup = function()
	db.private.init()
	return {
		success = true,
		requires = {
			"core.dirman",
			"core.dirman.utils",
			"core.integrations.roam.treesitter",
			"core.integrations.roam.meta",
		},
	}
end
db.config.private = {
	db_path = vim.fn.stdpath("data") .. "/roam.db",
}
db.private = {
	init = function()
		db.notes = sqlite.tbl("notes", {
			id = { type = "text", primary = true, required = true },
			path = { type = "text", required = true, unique = true },
			workspace = { type = "text", required = true },
			title = { type = "text", required = true },
		})
		db.links = sqlite.tbl("links", {
			id = true,
			source = {
				reference = "notes.id",
				required = true,
				on_delete = "cascade",
				on_update = "cascade",
			},
			target = {
				reference = "notes.id",
				required = true,
				on_delete = "cascade",
				on_update = "cascade",
			},
		})
		db.sql = sqlite({ uri = db.config.private.db_path, notes = db.notes, links = db.links })
	end,
	clean_db_file = function()
		-- first close all open neorg buffers
		local ok, _ = pcall(vim.cmd, "Neorg return")
		if not ok then
			vim.notify(
				"Neorg-roam db_sync error: failed to run Neorg return. db_sync cannot run with open neorg buffers.",
				vim.log.levels.ERROR
			)
			return false
		end
		ok, _ = pcall(os.remove, db.config.private.db_path)
		if not ok then
			vim.notify(
				"Neorg-roam db_sync error: Failed to remove db file at " .. db.config.private.db_path,
				vim.log.levels.ERROR
			)
			return false
		end
		ok, _ = pcall(db.private.init)
		if not ok then
			vim.notify(
				"Neorg-roam db_sync error: Failed to initialize db file at " .. db.config.private.db_path,
				vim.log.levels.ERROR
			)
			return false
		end
		return true
	end,
}
db.public = {
	sync = function()
		local ok = db.private.clean_db_file()
		if not ok then
			return nil
		end
		-- start with roam workspace, add support for other workspaces later.
		local wkspaces = db.required["core.dirman"].get_workspace_names()
		local notes_entries = {}
		local links = {}
		local bufnr = vim.api.nvim_create_buf(true, false)
		local curr_wksp = db.required["core.dirman"].get_current_workspace()[1]
		for _, wksp_name in ipairs(wkspaces) do
			db.required["core.dirman"].set_workspace(wksp_name)
			local wksp = db.required["core.dirman"].get_workspace(wksp_name)
			local wksp_files = db.required["core.dirman"].get_norg_files(wksp_name)
			for _, file in ipairs(wksp_files) do
				local metadata = get_or_generate_metadata(file, bufnr)
				notes_entries[file] = { path = file, id = metadata.id, workspace = wksp_name, title = metadata.title }
				local nodes = db.required["core.integrations.roam.treesitter"].get_norg_links(bufnr)
				for _, node in ipairs(nodes) do
					local expand = ""
					if starts_with(node, "$") then
						expand = db.required["core.dirman.utils"].expand_path(node)
					else
						expand = wksp .. "/" .. node .. ".norg"
					end
					table.insert(links, { from = file, to = expand })
				end
			end
		end
		vim.api.nvim_buf_delete(bufnr, {})
		db.required["core.dirman"].set_workspace(curr_wksp)
		local links_entries = generate_links_entries(links, notes_entries)
		db.notes:insert(process_notes_for_db_sync(notes_entries))
		db.links:insert(links_entries)
		vim.notify("Neorg-roam: regenerated db file.", vim.log.levels.INFO)
	end,

	sync_wksp = function(wksp)
		local results = {}
		db.sql:with_open(function()
			results =
				db.sql:eval("select * from notes join links on notes.id = links.source where notes.workspace = ?", wksp)
		end)
		vim.print(results)
	end,

	get_notes = function(wksp) end,

	get_backlinks = function(id) end,

	insert_note = function(note_data) end,

	insert_link = function(link_data) end,
}

return db
