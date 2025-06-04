local M = {}
local snowrest = require("snowvim.snowrest")
local config = require("snowvim.config")
local buf, win, tree
local row, col
local width, height = 40, 30

local function create_node(type, value, parent)
	local valid_types =
		{ root = true, database = true, schema = true, schema_object_type = true, table = true, column = true }
	if not valid_types[type] then
		error("Invalid node type: " .. tostring(type))
	end
	local expand = type ~= "column"
	return {
		type = type,
		value = value,
		parent = parent,
		children = {},
		line = nil,
		expand = expand,
	}
end

tree = create_node("root", "Databases")

local function add_child(parent, child)
	child.parent = parent
	table.insert(parent.children, child)
end

local function populate_node_async(node, callback)
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
	elseif node.type == "table" then
		local table_name = node.value
		local schema_name = node.parent.parent.value
		local database_name = node.parent.parent.parent.value
		local table_data = snowrest.get_columns(database_name, schema_name, table_name)
		local columns_data = table_data["columns"]
		for _, column_entry in ipairs(columns_data) do
			local column_node = create_node("column", column_entry["name"])
			vim.notify(vim.inspect(column_entry))
			column_node.datatype = column_entry["datatype"]
			add_child(node, column_node)
		end
	end
	callback()
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

	if node.type == "column" then
		text_representation = { node.value .. " (" .. node.datatype .. ")" }
	else
		text_representation = { node.value }
	end
	node.line = line_number
	line_number = line_number + 1
	if not node.expand then
		return text_representation
	end

	-- This is ridiculous
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
		for _, schema_object in ipairs(node.children) do
			local schema_object_text_representation = render(schema_object)
			for _, line in ipairs(schema_object_text_representation) do
				table.insert(text_representation, indent .. line)
			end
		end
	elseif node.type == "table" then
		for _, column in ipairs(node.children) do
			local column_text_representation = render(column)
			for _, line in ipairs(column_text_representation) do
				table.insert(text_representation, indent .. line)
			end
		end
	end

	return text_representation
end

local function create_window()
	vim.notify("Creating window")
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		vim.notify("Invalid buffer", vim.log.levels.ERROR)
		return
	end
	row = math.floor((vim.o.lines - height) / 2)
	col = math.floor((vim.o.columns - width) / 2)

	win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	})
end

local function display()
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		vim.notify("Invalid buffer", vim.log.levels.ERROR)
		return
	end
	if not win or not vim.api.nvim_win_is_valid(win) then
		create_window()
	end
	local lines = render(tree)
	vim.api.nvim_buf_set_option(buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_set_current_win(win)
end

local function expand_node()
	if not win or not vim.api.nvim_win_is_valid(win) then
		return
	end
	local current_line_number = vim.api.nvim_win_get_cursor(win)[1]
	vim.notify("Current line number: " .. current_line_number)
	local node_in_line = get_node_in_line(tree, current_line_number)
	node_in_line.expand = true
	if not node_in_line then
		vim.notify("No node found at line " .. current_line_number, vim.log.levels.WARN)
		return
	end
	if #node_in_line.children == 0 then
		populate_node_async(node_in_line, display)
	end
	display()
end

local function collapse_node()
	local current_line_number = vim.api.nvim_win_get_cursor(win)[1]
	vim.notify("Current line number: " .. current_line_number)
	local node_in_line = get_node_in_line(tree, current_line_number)
	node_in_line.expand = false
	display()
end

local function yank_node(do_fqdn)
	return function()
		local current_line_number = vim.api.nvim_win_get_cursor(win)[1]
		local node_in_line = get_node_in_line(tree, current_line_number)
		if not node_in_line then
			vim.notify("No node found at line " .. current_line_number, vim.log.levels.WARN)
			return
		end
		if node_in_line.type == "root" or node_in_line.type == "schema_object_type" then
			return
		end
		local text = ""
		if node_in_line.type == "column" then
			local column_name = node_in_line.value
			--local datatype = node_in_line.datatype
			text = column_name
		else
			local name = node_in_line.value
			if not do_fqdn then
				text = node_in_line.value
			else
				if node_in_line.type == "database" then
					text = node_in_line.value
				elseif node_in_line.type == "schema" then
					text = node_in_line.parent.value .. "." .. node_in_line.value
				elseif node_in_line.type == "table" or node_in_line.type == "view" then
					text = node_in_line.parent.parent.parent.value
						.. "."
						.. node_in_line.parent.parent.value
						.. "."
						.. node_in_line.value
				end
			end
		end
		vim.notify("Yanked: " .. text)
		vim.fn.setreg("+", text)
	end
end

function M.open_tree()
	if not buf then
		buf = vim.api.nvim_create_buf(false, true)
	end

	vim.keymap.set("n", "l", expand_node, { buffer = buf })
	vim.keymap.set("n", "h", collapse_node, { buffer = buf })
	vim.keymap.set("n", "q", "<cmd>bd!<CR>", { buffer = buf })
	vim.keymap.set("n", "D", display, { buffer = buf })
	vim.keymap.set("n", "y", yank_node(false), { buffer = buf })
	vim.keymap.set("n", "Y", yank_node(true), { buffer = buf })
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_set_current_win(win)
		return
	end

	if #tree.children == 0 then
		populate_node_async(tree, display)
	end
	display()
end

function M.setup(opts)
	config.setup(opts)
end

return M
