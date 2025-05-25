local M = {}

local curl = require("plenary.curl")
local my_toml = require("my_toml")

local connections = my_toml.get_connections()
local connection = connections["devpass"]

local account = connection["account"]
local bearer = connection["password"]
local LOCATION_TEMPLATE = "https://{account}.snowflakecomputing.com/api/v2/"

local function format_url(template, values)
	return template:gsub("{(%w+)}", function(key)
		return values[key]
	end)
end

local url = format_url(LOCATION_TEMPLATE, { account = account })

function M.get_databases()
	local response = curl.get(url .. "databases", {
		headers = {
			Authorization = "Bearer " .. bearer,
		},
	})

	local ok, parsed = pcall(vim.json.decode, response.body)

	return parsed
end

function M.get_schemas(database)
	local response = curl.get(url .. "databases/" .. database .. "/schemas", {
		headers = {
			Authorization = "Bearer " .. bearer,
		},
	})

	local ok, parsed = pcall(vim.json.decode, response.body)

	return parsed
end

function M.get_tables(database, schema)
	local response = curl.get(url .. "databases/" .. database .. "/schemas/" .. schema .. "/tables", {
		headers = {
			Authorization = "Bearer " .. bearer,
		},
	})

	local ok, parsed = pcall(vim.json.decode, response.body)

	return parsed
end

return M
