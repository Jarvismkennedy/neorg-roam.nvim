local sqlite = require("sqlite")

local db = {}

db.init = function()
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
	local db_path = vim.fn.stdpath("data") .. "roam.db"
	sqlite({ uri = db_path, notes = db.notes, links = db.links })
end

db.sync = function(wksps) end

db.sync_wksp = function(wksp) end

db.get_notes = function(wksp) end

db.get_backlinks = function(id) end

db.insert_note = function(note_data) end

db.insert_link = function(link_data) end

return db
