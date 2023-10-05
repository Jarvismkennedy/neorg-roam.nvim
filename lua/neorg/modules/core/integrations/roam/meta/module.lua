local neorg = require("neorg.core")

local meta = neorg.modules.create("core.integrations.roam.meta")
local generate_uuid = function()
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	math.randomseed(os.clock())
	return (
		string.gsub(template, "[xy]", function(c)
			local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
			return string.format("%x", v)
		end)
	)
end
-- get_timezone_offset and get_timestamp taken directly from neorg source code to match its
-- defaults.
local function get_timezone_offset()
	-- http://lua-users.org/wiki/TimeZone
	-- return the timezone offset in seconds, as it was on the time given by ts
	-- Eric Feliksik
	local utcdate = os.date("!*t", 0)
	local localdate = os.date("*t", 0)
	localdate.isdst = false -- this is the trick
	return os.difftime(os.time(localdate), os.time(utcdate))
end

local function get_timestamp()
	-- generate a ISO-8601 timestamp
	-- example: 2023-09-05T09:09:11-0500
	local tz_offset = get_timezone_offset()
	local h, m = math.modf(tz_offset / 3600)
	return os.date("%Y-%m-%dT%H:%M:%S") .. string.format("%+.4d", h * 100 + m * 60)
end
local join_templates = function(t1, t2)
	local merged = {}
	local t1_map = {}
	for i, v in ipairs(t1) do
		t1_map[v[1]] = v
	end
	for i, v in ipairs(t2) do
		local key = v[1]
		if t1_map[key] == nil then
			table.insert(merged, v)
		else
			table.insert(merged, t1_map[key])
			t1_map[key] = nil
		end
	end
end
meta.setup = function()
	return {
		success = true,
		requires = {
			"core.integrations.roam.treesitter",
			"core.esupports.metagen",
		},
	}
end
meta.load = function() end
meta.config.private = {
	default_template = {
		{
			"title",
			function(buf)
				buf = buf or 0
				local t = ""
				vim.api.nvim_buf_call(buf, function()
					t = vim.fn.expand("%:p:t:r")
				end)
				return t
			end,
		},
		{ "id", generate_uuid },
		{ "created", get_timestamp },
		{ "updated", get_timestamp },
	},
}
meta.private = {
	create_metadata = function(buf, template)
		local lines = { "@document.meta" }
		for i, v in ipairs(template) do
			if type(v[2]) ~= "function" then
				error("neorg roam meta template must be function, found " .. type(v[2]) .. " at index " .. i)
			end
			table.insert(lines, string.format("%s: %s", v[1], v[2](buf)))
		end
		table.insert(lines, "@end")
		return lines
	end,
	insert_metadata = function(buf, lines, start_row, end_row) end,
}
meta.public = {

	update_or_inject_metadata = function(buf)
		local metadata_present = meta.required["core.esupports.metagen"].is_metadata_present(buf)
		if metadata_present then
			vim.cmd("Neorg update-metadata")
		else
			meta.inject_metadata(buf)
		end
	end,
	inject_metadata = function(buf, force, template)
		local present, user_data = meta.required["core.esupports.metagen"].is_metadata_present(buf)
		if not present or force then
			template = template and join_table(template, meta.config.private.default_template)
				or meta.config.private.default_template
			local metadata = meta.private.create_metadata(buf, template)
			vim.api.nvim_buf_set_lines(buf, user_data.range[1], user_data.range[2], false, metadata)
		end
	end,
	get_document_metadata = function(buf)
		return meta.required["core.integrations.roam.treesitter"].get_document_metadata(buf)
	end,
}
return meta
