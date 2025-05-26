# Snowvim

> [!WARNING]
> This is currently under development and not ready for production use.

Snowvim is a simple Neovim plug-in to get metadata information from Snowflake.

If you are looking for a typical database UI, you might want to check out
[dadbod](https://github.com/tpope/vim-dadbod) and
[dadbod-ui](https://github.com/kristijanhusak/vim-dadbod-ui) instead.

But if you want something simple and fast - just to look at metadata and fill in
SQL scripts, this might be the plug-in for you.

It integrates with `.snowflake/connections.toml`

## Requirements

- Currently we get the configuration from the `.snowflake/connections.toml` fie.
- We support password and the recommended programmatic access tokens (Which are
specified in the password field of the TOML file, anyway)

> [!NOTE]
> If you are interested in other forms of authentication, please open
> an issue or submit a PR.

## Installation

Example with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  {
    "tiagoantao/snow.nvim",
    opts = {
      connection_profile = "devpass",
    },
    requires = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
  },
}
```

> [!NOTE]
> `connection_profile` is the name of the connection profile in `connections.toml`
> If you leave it empty, then it will be `default`
