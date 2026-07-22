return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({ flavour = "mocha" })
      vim.cmd.colorscheme("catppuccin")
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { options = { theme = "auto", globalstatus = true } },
  },
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = { "NvimTreeToggle", "NvimTreeFocus", "NvimTreeFindFile" },
    opts = function()
      local api = require("nvim-tree.api")
      local function on_attach(bufnr)
        api.config.mappings.default_on_attach(bufnr)
        vim.keymap.set("n", "yp", api.fs.copy.relative_path, { buffer = bufnr, desc = "Copy relative path" })
        vim.keymap.set("n", "yP", api.fs.copy.absolute_path, { buffer = bufnr, desc = "Copy absolute path" })
      end
      return {
        on_attach = on_attach,
        view = { width = 36 },
        git = { enable = true },
        renderer = {
          icons = {
            show = { git = true, folder = true, file = true },
            glyphs = {
              git = {
                unstaged = "M",
                staged = "S",
                unmerged = "U",
                renamed = "R",
                untracked = "?",
                deleted = "D",
                ignored = "I",
              },
            },
          },
        },
      }
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help" },
    },
    opts = {},
  },
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = true,
      current_line_blame_opts = {
        delay = 1000,
        virt_text_pos = "eol",
      },
      current_line_blame_formatter = "    <author>, <author_time:%Y-%m-%d> - <summary>",
    },
  },
  {
    "akinsho/bufferline.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    opts = {
      options = {
        show_close_icon = true,
        diagnostics = "nvim_lsp",
        diagnostics_indicator = function(_, _, diagnostics_dict)
          local s = " "
          for e, n in pairs(diagnostics_dict) do
            local sym = e == "error" and "E"
              or e == "warning" and "W"
              or e == "info" and "I"
              or e == "hint" and "H"
            s = s .. n .. sym
          end
          return s
        end,
        offsets = {
          { filetype = "NvimTree", text = "File Explorer", highlight = "Directory", padding = 1 },
        },
        hover = { enabled = true, delay = 200, reveal = { "close" } },
      },
    },
  },
  {
    "petertriho/nvim-scrollbar",
    opts = {
      handlers = {
        cursor = true,
        search = false,
        diagnostic = true,
        gitsigns = true,
        handle = true,
      },
    },
  },
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-buffer",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()
      cmp.setup({
        snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
            else fallback() end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then luasnip.jump(-1)
            else fallback() end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({ { name = "luasnip" }, { name = "nvim_lsp" }, { name = "path" } }, { { name = "buffer" } }),
      })
    end,
  },
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    opts = {},
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig", "hrsh7th/cmp-nvim-lsp" },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local servers = { "lua_ls", "ts_ls", "jsonls", "bashls" }
      for _, server in ipairs(servers) do
        vim.lsp.config(server, { capabilities = capabilities })
        vim.lsp.enable(server)
      end
      require("mason-lspconfig").setup({
        automatic_enable = false,
        ensure_installed = { "lua_ls", "ts_ls", "jsonls", "bashls" },
      })
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local map = function(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = args.buf, desc = desc })
          end
          map("gd", vim.lsp.buf.definition, "Definition")
          map("gr", vim.lsp.buf.references, "References")
          map("K", vim.lsp.buf.hover, "Hover")
          map("<leader>rn", vim.lsp.buf.rename, "Rename")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("<leader>lf", function() vim.lsp.buf.format({ async = true }) end, "Format")
        end,
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup {}
    end,
  },
}
