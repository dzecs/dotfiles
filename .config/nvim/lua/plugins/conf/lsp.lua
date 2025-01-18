-- [[ Configure LSP ]]
-- Setup neovim lua configuration
require("neodev").setup()

local custom_format = function()
	if vim.bo.filetype == "templ" then
		local bufnr = vim.api.nvim_get_current_buf()
		local filename = vim.api.nvim_buf_get_name(bufnr)
		local cmd = "templ fmt " .. vim.fn.shellescape(filename)
		vim.fn.jobstart(cmd, {
			on_exit = function()
				-- reload the buffer only if it's still the current buffer
				if vim.api.nvim_get_current_buf() == bufnr then
					vim.cmd("e!")
				end
			end,
		})
	else
		vim.cmd("Format")
	end
end

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
	callback = function(event)
		local map = function(keys, func, desc, mode)
			mode = mode or "n"
			vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
		end

		local client = vim.lsp.get_client_by_id(event.data.client_id)
		if client then
			client.server_capabilities.semanticTokensProvider = nil
		end
		-- keybinds
		map("<leader>lr", vim.lsp.buf.rename, "[l]sp [r]ename")
		map("<leader>la", vim.lsp.buf.code_action, "[l]sp code [a]ction")
		map("<leader>lf", custom_format, "[l]sp custom [f]ormat")

		map("gd", vim.lsp.buf.definition, "[g]oto [d]efinition")
		map("gr", require("telescope.builtin").lsp_references, "[g]oto [r]eferences")
		map("gI", vim.lsp.buf.implementation, "[g]oto [I]mplementation")
		map("<leader>D", vim.lsp.buf.type_definition, "type [D]efinition")
		map("<leader>ds", require("telescope.builtin").lsp_document_symbols, "[d]ocument [s]ymbols")
		map("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "[w]orkspace [s]ymbols")

		-- see `:help K` for why this keymap
		map("K", vim.lsp.buf.hover, "hover documentation")
		map("<C-k>", vim.lsp.buf.signature_help, "signature documentation")

		-- lesser used lsp functionality
		map("gD", vim.lsp.buf.declaration, "[g]oto [d]eclaration")
		map("<leader>wa", vim.lsp.buf.add_workspace_folder, "[w]orkspace [a]dd folder")
		map("<leader>wr", vim.lsp.buf.remove_workspace_folder, "[w]orkspace [r]emove folder")
		map("<leader>wl", function()
			print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
		end, "[w]orkspace [l]ist folders")
	end,
})

local is_nixos = require("core.utils").detect_nixos()
local lspconfig = require("lspconfig")
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = vim.tbl_deep_extend("force", capabilities, require("blink.cmp").get_lsp_capabilities())

local servers = {
	astro = {},
	svelte = {},
	cssls = {},
	clangd = {},
	gopls = {},
	ts_ls = {},
	rust_analyzer = {
		cachePriming = { enable = false },
	},
	nixd = {
		cmd = { "nixd" },
		settings = {
			nixd = {
				nixpkgs = {
					expr = "import <nixpkgs> { }",
				},
				formatting = {
					command = { "nixfmt" },
				},
				options = {
					nixos = {
						expr = '(builtins.getFlake "'
							.. vim.loop.os_homedir()
							.. '/.config/nixos").nixosConfigurations.desktop.options',
					},
				},
			},
		},
	},
	-- htmx = {},
	tailwindcss = {},
	html = {
		filetypes = { "gotmpl" },
	},
	lua_ls = {
		Lua = {
			workspace = { checkThirdParty = false },
			telemetry = { enable = false },
			diagnostics = {
				disable = { "missing-fields" },
				globals = { "vim" },
			},
		},
	},
}
local function deep_merge_config(base, override)
	if override == nil then
		return base
	end

	local result = vim.deepcopy(base)

	for k, v in pairs(override) do
		if type(v) == "table" and type(result[k]) == "table" then
			result[k] = deep_merge_config(result[k], v)
		else
			result[k] = v
		end
	end

	return result
end

for server, config in pairs(servers) do
	servers[server] = deep_merge_config({
		capabilities = capabilities,
	}, config)
end

if is_nixos then
	for server, config in pairs(servers) do
		lspconfig[server].setup(config)
	end
else
	local ensure_installed = vim.tbl_keys(servers)
	vim.list_extend(ensure_installed, { "stylua" })

	require("mason").setup()
	require("mason-tool-installer").setup({ ensure_installed = ensure_installed })

	require("mason-lspconfig").setup({
		handlers = {
			function(server)
				lspconfig[server].setup(servers[server] or {})
			end,
		},
	})
end
