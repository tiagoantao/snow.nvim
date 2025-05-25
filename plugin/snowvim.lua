local snowvim = require("snowvim")

vim.api.nvim_create_user_command("LetItSnow", function()
	snowvim.open_tree()
end, {})
