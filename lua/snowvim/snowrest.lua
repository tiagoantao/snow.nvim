local M = {}

local curl = require("plenary.curl")
local my_toml = require("snowvim.toml")
local config = require("snowvim.config")

local LOCATION_TEMPLATE = "https://{account}.snowflakecomputing.com/api/v2/"

local function get_bearer_token()
	local connections = my_toml.get_connections()
	local connection = connections[config.opts.connection_profile]

	local bearer = connection["password"]
	return string.gsub(bearer, '"', "")
end

local function format_url(template, values)
	return template:gsub("{(%w+)}", function(key)
		return values[key]
	end)
end

local function get_api_url()
	local connections = my_toml.get_connections()
	local connection = connections[config.opts.connection_profile]
	local account = string.gsub(connection["account"], '"', "")
	local url = format_url(LOCATION_TEMPLATE, { account = account })
	return url
end

function M.get_databases()
	local bearer = get_bearer_token()
	local url = get_api_url()
	local response = curl.get(url .. "databases", {
		headers = {
			Authorization = "Bearer " .. bearer,
		},
	})

	local ok, parsed = pcall(vim.json.decode, response.body)

	return parsed
end

function M.get_schemas(database)
	local bearer = get_bearer_token()
	local url = get_api_url()
	local response = curl.get(url .. "databases/" .. database .. "/schemas", {
		headers = {
			Authorization = "Bearer " .. bearer,
		},
	})

	local ok, parsed = pcall(vim.json.decode, response.body)

	return parsed
end

function M.get_tables(database, schema)
	local bearer = get_bearer_token()
	local url = get_api_url()
	local response = curl.get(url .. "databases/" .. database .. "/schemas/" .. schema .. "/tables", {
		headers = {
			Authorization = "Bearer " .. bearer,
		},
	})

	local ok, parsed = pcall(vim.json.decode, response.body)

	return parsed
end

function M.get_columns(database_name, schema_name, table_name)
	local bearer = get_bearer_token()
	local url = get_api_url()
	local response =
		curl.get(url .. "databases/" .. database_name .. "/schemas/" .. schema_name .. "/tables/" .. table_name, {
			headers = {
				Authorization = "Bearer " .. bearer,
			},
		})

	local ok, parsed = pcall(vim.json.decode, response.body)

	return parsed
end

return M
