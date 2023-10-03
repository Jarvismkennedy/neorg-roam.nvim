local sqlite = require("sqlite")
local neorg = require("neorg.core")

local db = neorg.modules.create("core.integrations.roam.db")

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
			"core.integrations.treesitter",
		},
	}
end
db.public = {
	sync = function()
		local wkspaces = db.required["core.dirman"].get_workspace_names()
		-- start with just the roam db and see what happens.
		local wksp_files = db.required["core.dirman"].get_norg_files("roam")
		for i, file in ipairs(wksp_files) do
			local bufnr = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_buf_set_name(bufnr, file)
			vim.api.nvim_buf_call(bufnr, vim.cmd.edit)
			local metadata = db.required["core.integrations.treesitter"].get_document_metadata(bufnr)
			vim.print(metadata)
			end
		vim.print(wksp_files)
	end,

	sync_wksp = function(wksp) end,

	get_notes = function(wksp) end,

	get_backlinks = function(id) end,

	insert_note = function(note_data) end,

	insert_link = function(link_data) end,
}

return db
