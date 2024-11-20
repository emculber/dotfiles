return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		{ "folke/neodev.nvim", opts = {} },
	},
	config = function()
		local nvim_lsp = require("lspconfig")
		local mason_lspconfig = require("mason-lspconfig")

		local protocol = require("vim.lsp.protocol")

		local on_attach = function(client, bufnr)
			-- format on save
			if client.server_capabilities.documentFormattingProvider then
				vim.api.nvim_create_autocmd("BufWritePre", {
					group = vim.api.nvim_create_augroup("Format", { clear = true }),
					buffer = bufnr,
					callback = function()
						vim.lsp.buf.format()
					end,
				})
			end
		end

		local capabilities = require("cmp_nvim_lsp").default_capabilities()

		mason_lspconfig.setup_handlers({
			function(server)
				nvim_lsp[server].setup({
					capabilities = capabilities,
				})
			end,
			["cssls"] = function()
				nvim_lsp["cssls"].setup({
					on_attach = on_attach,
					capabilities = capabilities,
				})
			end,
			["tailwindcss"] = function()
				nvim_lsp["tailwindcss"].setup({
					on_attach = on_attach,
					capabilities = capabilities,
				})
			end,
			["html"] = function()
				nvim_lsp["html"].setup({
					on_attach = on_attach,
					capabilities = capabilities,
				})
			end,
			["jsonls"] = function()
				nvim_lsp["jsonls"].setup({
					on_attach = on_attach,
					capabilities = capabilities,
				})
			end,
			["eslint"] = function()
				nvim_lsp["eslint"].setup({
					on_attach = on_attach,
					capabilities = capabilities,
				})
			end,
			["pyright"] = function()
				nvim_lsp["pyright"].setup({
					on_attach = on_attach,
					capabilities = capabilities,
				})
			end,
			["gopls"] = function()
				nvim_lsp.gopls.setup({
					root_dir = nvim_lsp.util.root_pattern(".git", "go.mod", "go.work"),
					capabilities = capabilities,
					cmd = { "gopls" },
					filetypes = { "go", "gomod", "gowork", "gotmpl" },
					settings = {
						gopls = {
							completeUnimported = true,
							completeFunctionCalls = true,
							usePlaceholders = false,
							--analyses = {},
							staticcheck = true,
							gofumpt = false,
						},
					},
				})
			end,
		})
	end,
}

-- return {
--   "neovim/nvim-lspconfig",
--
--   dependencies = {
--     "williamboman/mason.nvim",         -- Will make sure we have access to the language servers.
--     "williamboman/nvim-lsp-installer",
--     "williamboman/mason-lspconfig.nvim", -- Configure the automatic setup of every language server we install.
--
--     "hrsh7th/cmp-nvim-lsp",
--   },
--
--   config = function()
--     -- LSP servers and clients are able to communicate to each other what features they support.
--
--     --  By default, Neovim doesn't support everything that is in the LSP specification.
--     --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
--     --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
--     local capabilities = vim.tbl_deep_extend(
--       "force",
--       {},
--       vim.lsp.protocol.make_client_capabilities(),
--       require("cmp_nvim_lsp").default_capabilities()
--     )
--
--     local lspconfig = require("lspconfig")
--
--     -- Use mason to fetch LSPs that are independent of any installed on the system.
--     require("mason").setup({})
--     -- Configure the automatic setup of every language server installed.
--     require("mason-lspconfig").setup({
--       ensure_installed = {
--         "lua_ls", -- lua language server.
--         "gopls", -- Golang language server.
--         "ts_ls", -- Typescript language server.
--       },
--       handlers = {
--         function(server_name)
--           require("lspconfig")[server_name].setup({
--             capabilities = capabilities,
--           })
--         end,
--         ["lua_ls"] = function()
--           -- configure lua server (with special settings)
--           lspconfig.lua_ls.setup({
--             capabilities = capabilities,
--             settings = {
--               Lua = {
--                 -- make the language server recognize "vim" global
--                 diagnostics = {
--                   globals = { "vim" },
--                 },
--                 completion = {
--                   callSnippet = "Replace",
--                 },
--               },
--             },
--           })
--         end,
--         ["gopls"] = function()
--           lspconfig.gopls.setup({
--             root_dir = lspconfig.util.root_pattern(".git", "go.mod", "go.work"),
--             capabilities = capabilities,
--             cmd = { "gopls" },
--             filetypes = { "go", "gomod", "gowork", "gotmpl" },
--             settings = {
--               gopls = {
--                 completeUnimported = true,
--                 completeFunctionCalls = true,
--                 usePlaceholders = false,
--                 --analyses = {},
--                 staticcheck = true,
--                 gofumpt = false,
--               },
--             },
--           })
--         end,
--       },
--     })
--
--     -- Automatic action performed on events.
--     vim.api.nvim_create_autocmd("LspAttach", {
--       group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
--       callback = function(args)
--         -- NOTE: Remember that Lua is a real programming language, and as such it is possible
--         -- to define small helper and utility functions so you don't have to repeat yourself.
--         --
--         -- In this case, we create a function that lets us more easily define mappings specific
--         -- for LSP related items. It sets the mode, buffer and description for us each time.
--         local map = function(keys, func, desc, mode)
--           mode = mode or "n"
--           vim.keymap.set(mode, keys, func, { buffer = args.buf, desc = "LSP: " .. desc })
--         end
--
--         map("K", "<cmd>lua vim.lsp.buf.hover()<cr>", "[G]oto [D]efinition")
--         map("gd", "<cmd>lua vim.lsp.buf.definition()<cr>", "[G]oto [D]efinition")
--         map("gD", "<cmd>lua vim.lsp.buf.declaration()<cr>", "[G]oto [D]eclaration")
--         map("gi", "<cmd>lua vim.lsp.buf.implementation()<cr>", "[G]oto [I]mplementation")
--         map("go", "<cmd>lua vim.lsp.buf.type_definition()<cr>", "Type [D]efinition")
--         map("gr", "<cmd>lua vim.lsp.buf.references()<cr>", "[G]oto [R]eferences")
--         map("gh", "<cmd>lua vim.lsp.buf.signature_help()<cr>", "Display function signature [h]elp")
--         map("<C-s>", "<cmd>lua vim.lsp.buf.signature_help()<cr>", "Display function signature [h]elp", "i")
--         map("<F2>", "<cmd>lua vim.lsp.buf.rename()<cr>", "LSP rename all instances")
--         -- Execute a code action, usually your cursor needs to be on top of an error
--         -- or a suggestion from your LSP for this to activate.
--         map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction", { "n", "x" })
--         map("<F4>", "<cmd>lua vim.lsp.buf.code_action()<cr>", "")
--
--         local client = vim.lsp.get_client_by_id(args.data.client_id)
--
--         if client.supports_method("textDocument/inlayHint") then
--           vim.lsp.inlay_hint.enable(true)
--         end
--
--         if client.supports_method("textDocument/formatting") then
--           -- Format the current buffer on save.
--           vim.api.nvim_create_autocmd("BufWritePre", {
--             buffer = args.buf,
--             callback = function()
--               vim.lsp.buf.format({ bufnr = args.buf, id = client.id })
--             end,
--           })
--
--           -- Golang specific actions.
--           vim.api.nvim_create_autocmd("BufWritePre", {
--             pattern = "*.go",
--             callback = function()
--               local params = vim.lsp.util.make_range_params()
--               params.context = { only = { "source.organizeImports" } }
--               -- buf_request_sync defaults to a 1000ms timeout. Depending on your
--               -- machine and codebase, you may want longer. Add an additional
--               -- argument after params if you find that you have to write the file
--               -- twice for changes to be saved.
--               -- E.g., vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 3000)
--               local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params)
--               for cid, res in pairs(result or {}) do
--                 for _, r in pairs(res.result or {}) do
--                   if r.edit then
--                     local enc = (vim.lsp.get_client_by_id(cid) or {}).offset_encoding or "utf-16"
--                     vim.lsp.util.apply_workspace_edit(r.edit, enc)
--                   end
--                 end
--               end
--             end,
--           })
--         end
--       end,
--     })
--   end,
-- }
