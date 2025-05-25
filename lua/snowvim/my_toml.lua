local M = {}
local ts = vim.treesitter
local parsers = require("nvim-treesitter.parsers")

function M.get_connections()
	local path = vim.fn.expand("~/.snowflake/connections.toml")

	local lines = {}
	for line in io.lines(path) do
		table.insert(lines, line)
	end
	local buf = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_set_current_buf(buf)
	local parser = parsers.get_parser(0, "toml")
	local tree = parser:parse()[1]
	local root = tree:root()

	local parsed_query = ts.query.parse(
		"toml",
		[[
      (table (bare_key) @table_name)
      (pair (bare_key) @key (_) @value)
    ]]
	)

	local connections = {}
	local current_table = nil
	local current_key = nil

	for id, node in parsed_query:iter_captures(root, 0, 0, -1) do
		local name = parsed_query.captures[id]
		local text = ts.get_node_text(node, 0)

		if name == "table_name" then
			connections[text] = {}
			current_table = text
		elseif name == "key" then
			current_key = text
		elseif name == "value" then
			connections[current_table][current_key or "???"] = text
			current_key = nil
		end
	end

	vim.api.nvim_buf_delete(0, { force = true })
	return connections
end

return M
