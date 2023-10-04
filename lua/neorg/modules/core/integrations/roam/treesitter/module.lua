local neorg = require("neorg.core")

local treesitter = neorg.modules.create("core.integrations.roam.treesitter")

treesitter.setup = function()
	return {
		success = true,
		requires = {
			"core.integrations.treesitter",
		},
	}
end

treesitter.public = { 
	get_document_metadata = function(bufnr)
		return treesitter.required["core.integrations.treesitter"].get_document_metadata(bufnr)
	end
}

return treesitter
