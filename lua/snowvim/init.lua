local M = {}
local snowrest = require("snowvim.snowrest")
local config = require("snowvim.config")
local buf, win

local function create_node(type, value, parent)
	local valid_types = { root = true, database = true, schema = true, schema_object_type = true, table = true }
	if not valid_types[type] then
		error("Invalid node type: " .. tostring(type))
	end
	return {
		type = type,
		value = value,
		parent = parent,
		children = {},
		line = nil,
		expand = true,
	}
end

local function add_child(parent, child)
	child.parent = parent
	table.insert(parent.children, child)
end

local tree = create_node("root", "Databases")

local function populate_node(node)
	if node.type == "root" then
		local database_data = snowrest.get_databases()
		for _, database_entry in ipairs(database_data) do
			local database_node = create_node("database", database_entry["name"])
			add_child(tree, database_node)
		end
	elseif node.type == "database" then
		local schema_data = snowrest.get_schemas(node.value)
		for _, schema_entry in ipairs(schema_data) do
			local schema_node = create_node("schema", schema_entry["name"])
			add_child(node, schema_node)
		end
	elseif node.type == "schema" then
		local table_holder = create_node("schema_object_type", "Tables")
		add_child(node, table_holder)
		local table_data = snowrest.get_tables(node.parent.value, node.value)
		for _, table_entry in ipairs(table_data) do
			local table_node = create_node("table", table_entry["name"])
			add_child(table_holder, table_node)
		end
		add_child(node, create_node("schema_object_type", "Views"))
	end
end

local function get_node_in_line(node, line_number)
	if node.line == line_number then
		return node
	end

	if not node.expand then
		return nil
	end
	for _, child in ipairs(node.children) do
		local found_node = get_node_in_line(child, line_number)
		if found_node then
			return found_node
		end
	end

	return nil
end

local line_number = 1

local function render(node)
	if node.type == "root" then
		line_number = 1
	end
	local text_representation = {}
	local indent = "  "

	text_representation = { node.value }
	node.line = line_number
	line_number = line_number + 1
	if not node.expand then
		return text_representation
	end

	if node.type == "root" then
		for _, database_entry in ipairs(node.children) do
			local database_text_representation = render(database_entry)
			for _, line in ipairs(database_text_representation) do
				table.insert(text_representation, indent .. line)
			end
		end
	elseif node.type == "database" then
		for _, schema_entry in ipairs(node.children) do
			local schema_text_representation = render(schema_entry)
			for _, line in ipairs(schema_text_representation) do
				table.insert(text_representation, indent .. line)
			end
		end
	elseif node.type == "schema" then
		for _, schema_type_entry in ipairs(node.children) do
			local schema_type_text_representation = render(schema_type_entry)
			for _, line in ipairs(schema_type_text_representation) do
				table.insert(text_representation, indent .. line)
			end
		end
	elseif node.type == "schema_object_type" then
		for _, schema_real_type_entry in ipairs(node.children) do
			local schema_real_type_text_representation = render(schema_real_type_entry)
			for _, line in ipairs(schema_real_type_text_representation) do
				table.insert(text_representation, indent .. line)
			end
		end
	end

	return text_representation
end

local function display()
	local lines = render(tree)
	vim.api.nvim_buf_set_option(buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

local function expand_node()
	local current_line_number = vim.api.nvim_win_get_cursor(0)[1]
	vim.notify("Current line number: " .. current_line_number)
	local node_in_line = get_node_in_line(tree, current_line_number)
	node_in_line.expand = true
	if #node_in_line.children == 0 then
		populate_node(node_in_line)
	end
	vim.notify("Node in line: " .. vim.inspect(node_in_line))
	display()
end

local function collapse_node()
	local current_line_number = vim.api.nvim_win_get_cursor(0)[1]
	vim.notify("Current line number: " .. current_line_number)
	local node_in_line = get_node_in_line(tree, current_line_number)
	node_in_line.expand = false
	display()
end

function M.open_tree()
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_set_current_win(win)
		return
	end

	buf = vim.api.nvim_create_buf(false, true)
	local width, height = 50, 30
	local row = (vim.o.lines - height) / 2
	local col = (vim.o.columns - width) / 2

	win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	})
	if #tree.children == 0 then
		populate_node(tree)
	end
	vim.keymap.set("n", "l", expand_node, { buffer = buf })
	vim.keymap.set("n", "h", collapse_node, { buffer = buf })
	vim.keymap.set("n", "q", "<cmd>bd!<CR>", { buffer = buf })
	vim.keymap.set("n", "D", display, { buffer = buf })
	display()
end

function M.setup(opts)
	config.setup(opts)
end

return M
