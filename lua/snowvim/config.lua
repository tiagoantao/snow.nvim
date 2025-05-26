local M = {}

local defaults = {
	connection_profile = "default",
}

function M.setup(opts)
	M.opts = vim.tbl_deep_extend("force", defaults, opts or {})
	if M.opts.connection_profile == nil then
		M.opts.connection_profile = "default"
	end
	if M.opts.connection_profile == "" then
		M.opts.connection_profile = "default"
	end
	vim.notify("Snowflake connection profile: " .. M.opts.connection_profile)
end
return M
