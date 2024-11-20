function SetGlobalStyle(color)
    color = color or "rose-pine-moon"
    vim.cmd.colorscheme(color)

    --vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    --vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
end

return {
    {

        -- https://github.com/rose-pine/neovim
        "rose-pine/neovim",
        name = "rose-pine",

        config = function()
            require("rose-pine").setup({
                disable_background = true,
                styles = {
                    bold = true,
                    italic = false,
                    transparency = true,
                },
            })

            SetGlobalStyle("rose-pine-moon")
        end
    },
    --{
    --    "folke/tokyonight.nvim",
    --    name = "tokyonight",
    --    --priority = 1000, -- Make sure to load this before all the other start plugins.
    --    config = function()
    --        require("tokyonight").setup({
    --            -- use the night style
    --            style = "night",
    --            -- disable italic for functions
    --            styles = {
    --                functions = {}
    --            },
    --            -- Change the "hint" color to the "orange" color, and make the "error" color bright red
    --            on_colors = function(colors)
    --                colors.hint = colors.orange
    --                colors.error = "#ff0000"
    --            end
    --        })

    --        --SetGlobalStyle('tokyonight-night')
    --    end
    --},
    --{
    --    "catppuccin/nvim",
    --    name = "catppuccin",
    --    --priority = 1000,
    --    config = function()
    --        require("catppuccin").setup({
    --            flavour = "frappe", -- latte, frappe, macchiato, mocha
    --            background = {      -- :h background
    --                light = "latte",
    --                dark = "mocha",
    --            },
    --            transparent_background = false, -- disables setting the background color.
    --            show_end_of_buffer = false,     -- shows the '~' characters after the end of buffers
    --            term_colors = false,            -- sets terminal colors (e.g. `g:terminal_color_0`)
    --            dim_inactive = {
    --                enabled = false,            -- dims the background color of inactive window
    --                shade = "dark",
    --                percentage = 0.15,          -- percentage of the shade to apply to the inactive window
    --            },
    --            no_italic = false,              -- Force no italic
    --            no_bold = false,                -- Force no bold
    --            no_underline = false,           -- Force no underline
    --            styles = {                      -- Handles the styles of general hi groups (see `:h highlight-args`):
    --                comments = { "italic" },    -- Change the style of comments
    --                conditionals = { "italic" },
    --                loops = {},
    --                functions = {},
    --                keywords = {},
    --                strings = {},
    --                variables = {},
    --                numbers = {},
    --                booleans = {},
    --                properties = {},
    --                types = {},
    --                operators = {},
    --                -- miscs = {}, -- Uncomment to turn off hard-coded styles
    --            },
    --            color_overrides = {},
    --            custom_highlights = {},
    --            default_integrations = true,
    --            integrations = {
    --                cmp = true,
    --                gitsigns = true,
    --                nvimtree = true,
    --                treesitter = true,
    --                notify = false,
    --                mini = {
    --                    enabled = true,
    --                    indentscope_color = "",
    --                },
    --                -- For more plugins integrations please scroll down (https://github.com/catppuccin/nvim#integrations)
    --            },
    --        })

    --        SetGlobalStyle("catppuccin")
    --    end
    --},
    -- {
    --     "ellisonleao/gruvbox.nvim",
    --     name = "gruvbox",
    --     config = function()
    --         require("gruvbox").setup({
    --             terminal_colors = true, -- add neovim terminal colors
    --             undercurl = true,
    --             underline = false,
    --             bold = true,
    --             italic = {
    --                 strings = false,
    --                 emphasis = false,
    --                 comments = false,
    --                 operators = false,
    --                 folds = false,
    --             },
    --             strikethrough = true,
    --             invert_selection = false,
    --             invert_signs = false,
    --             invert_tabline = false,
    --             invert_intend_guides = false,
    --             inverse = true, -- invert background for search, diffs, statuslines and errors
    --             contrast = "",  -- can be "hard", "soft" or empty string
    --             palette_overrides = {},
    --             overrides = {},
    --             dim_inactive = false,
    --             transparent_mode = false,
    --         })

    --         SetGlobalStyle("gruvbox")
    --     end,
    -- },
}
