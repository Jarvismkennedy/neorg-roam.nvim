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

treesitter.config.private = {
	link_query = [[
		(link
			(link_location
				file: (link_file_text) @ft
			)
		)
	]],
}
treesitter.public = {
	get_document_metadata = function(bufnr)
		return treesitter.required["core.integrations.treesitter"].get_document_metadata(bufnr)
	end,
	get_norg_links = function(bufnr)
		local nodes = {}
		treesitter.required["core.integrations.treesitter"].execute_query(
			treesitter.config.private.link_query,
			function(query, id, node, metadata)
				table.insert(nodes, treesitter.required["core.integrations.treesitter"].get_node_text(node,bufnr))
			end,
			bufnr,
			0,
			-1
		)
		return nodes
	end,
}

return treesitter
