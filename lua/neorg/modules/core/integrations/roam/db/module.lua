local sqlite = require("sqlite")
local neorg = require("neorg.core")

local db = neorg.modules.create("core.integrations.roam.db")
local function starts_with(str, start)
	return str:sub(1, #start) == start
end
db.setup = function()
	db.notes = sqlite.tbl("notes", {
		id = true,
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
	local db_path = vim.fn.stdpath("data") .. "/roam.db"
	sqlite({ uri = db_path, notes = db.notes, links = db.links })
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
db.public = {
	sync = function()
		-- start with roam workspace, add support for other workspaces later.
		local wksp = db.required["core.dirman"].get_workspace("roam")
		local wksp_files = db.required["core.dirman"].get_norg_files("roam")
		local bufnr = vim.api.nvim_create_buf(true, false)
		local notes_entries = {}
		local links = {}
		for _, file in ipairs(wksp_files) do
			vim.api.nvim_buf_set_name(bufnr, file)
			vim.api.nvim_buf_call(bufnr, vim.cmd.edit)
			local metadata = db.required["core.integrations.roam.meta"].get_document_metadata(bufnr)
			if metadata == nil or metadata.id == nil then
				metadata = db.required["core.integrations.roam.meta"].inject_metadata(bufnr, true, nil)
				vim.api.nvim_buf_call(bufnr, function()
					vim.cmd([[write]])
				end)
			end
			notes_entries[file] = { path = file, id = metadata.id, workspace = "roam", title = metadata.title }
			local nodes = db.required["core.integrations.roam.treesitter"].get_norg_links(bufnr)
			vim.print(nodes)
			if nodes ~= nil and #nodes > 0 then
				for i, node in ipairs(nodes) do
					table.insert(links, { from = file, to = db.required["core.dirman.utils"].expand_path(node) })
				end
			end
		end
		vim.print(links)
		vim.api.nvim_buf_delete(bufnr, {})
	end,

	sync_wksp = function(wksp) end,

	get_notes = function(wksp) end,

	get_backlinks = function(id) end,

	insert_note = function(note_data) end,

	insert_link = function(link_data) end,
}

return db
