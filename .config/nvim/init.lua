-- divvy · config de nvim (aislada en el proyecto vía XDG_CONFIG_HOME)
vim.g.mapleader = " "

local o = vim.opt
o.number = true
o.termguicolors = true        -- requiere terminal con true color
o.mouse = "a"
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.smartindent = true
o.ignorecase = true
o.smartcase = true
o.signcolumn = "yes"
o.cursorline = true
o.wrap = false
o.scrolloff = 6
o.clipboard = "unnamedplus"
-- nvim corre como servidor y yazi le manda archivos por --remote. CUALQUIER
-- prompt modal congela el bucle de eventos y bloquea TODO el RPC: las aperturas
-- desde yazi se cuelgan y se acumulan procesos `nvim --remote` zombie. Tres
-- fuentes nos mordieron, todas terminan en wait_return ("Press ENTER"):
--   1) E325 "ATTENTION" (swap ya existe)         -> swapfile=false + shortmess A
--   2) la linea de info al editar ('"x" Nl Nb')  -> shortmess F
--   3) mensajes de arranque (treesitter/mason/LSP via vim.notify): en el panel
--      editor (ESTRECHO, ~40 cols) el texto ENVUELVE en varias lineas -> scroll
--      -> wait_return. No basta con truncar: ni una sola linea cabe seguro. Por
--      eso vim.notify NO toca la pantalla; va a un log + :DivvyMessages.
o.swapfile = false
o.more = false                       -- sin pager modal en listados largos
o.report = 9999                      -- sin "N lines changed"
o.shortmess:append("AaoOtTWIcCF")    -- mensajes cortos/sin intro/sin file-info

-- vim.notify NUNCA debe escribir en pantalla (ver punto 3 arriba). Lo mandamos
-- a un log y a un historial en memoria, sin echo => imposible que congele el RPC.
do
  local logfile = vim.fn.stdpath("state") .. "/divvy-notify.log"
  _G.divvy_notes = {}
  local function record(msg)
    if type(msg) == "table" then msg = table.concat(msg, " ") end
    msg = tostring(msg)
    table.insert(_G.divvy_notes, msg)
    pcall(function()
      local f = io.open(logfile, "a")
      if f then f:write(os.date("%H:%M:%S ") .. msg:gsub("%s+", " ") .. "\n"); f:close() end
    end)
  end
  vim.notify = function(msg) record(msg) end
  vim.notify_once = vim.notify
end
-- ver los avisos acumulados sin riesgo de congelar (abre un scratch buffer)
vim.api.nvim_create_user_command("DivvyMessages", function()
  vim.cmd("botright new")
  vim.bo.buftype = "nofile"; vim.bo.bufhidden = "wipe"; vim.bo.swapfile = false
  vim.api.nvim_buf_set_lines(0, 0, -1, false, _G.divvy_notes or {})
end, {})

-- tema seleccionado: se lee de <proyecto>/.theme (lo escribe divvy-theme)
local proj = vim.fn.fnamemodify(vim.fn.stdpath("config"), ":h:h") -- $DIR/.config/nvim -> $DIR
local function read_theme()
  local f = io.open(proj .. "/.theme", "r")
  if not f then return "dracula" end
  local t = ((f:read("*l") or "")):gsub("%s+", "")
  f:close()
  return t ~= "" and t or "dracula"
end
local THEME = read_theme()
-- solo el colorscheme; lualine usa theme="auto" (deriva del colorscheme activo),
-- asi no dependemos de que lualine traiga un theme con ese nombre (catppuccin y
-- tokyonight NO vienen bundled -> daban "theme not found, falling back to auto").
local MAP = {
  dracula    = { cs = "dracula" },
  catppuccin = { cs = "catppuccin-mocha" },
  tokyonight = { cs = "tokyonight" },
  gruvbox    = { cs = "gruvbox" },
  nord       = { cs = "nord" },
}
local SEL = MAP[THEME] or MAP.dracula

-- bootstrap de lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- temas (todos instalados; se aplica el elegido en .theme)
  { "Mofiqul/dracula.nvim",     lazy = false, priority = 1000 },
  { "catppuccin/nvim",          name = "catppuccin", lazy = false, priority = 1000 },
  { "folke/tokyonight.nvim",    lazy = false, priority = 1000 },
  { "ellisonleao/gruvbox.nvim", lazy = false, priority = 1000 },
  { "shaunsingh/nord.nvim",     lazy = false, priority = 1000 },
  -- iconos
  { "nvim-tree/nvim-web-devicons" },
  -- barra de estado bonita
  { "nvim-lualine/lualine.nvim", config = function()
      require("lualine").setup({ options = { theme = "auto", globalstatus = true } })
    end },
  -- pestañas de archivos (cada archivo abierto desde yazi = una pestaña)
  { "akinsho/bufferline.nvim", dependencies = { "nvim-tree/nvim-web-devicons" }, config = function()
      require("bufferline").setup({
        options = { diagnostics = "nvim_lsp", separator_style = "thin", show_buffer_close_icons = true },
      })
      vim.keymap.set("n", "<Tab>",     "<cmd>BufferLineCycleNext<cr>", { desc = "Pestaña siguiente" })
      vim.keymap.set("n", "<S-Tab>",   "<cmd>BufferLineCyclePrev<cr>", { desc = "Pestaña anterior" })
      vim.keymap.set("n", "<leader>x", "<cmd>bdelete<cr>",            { desc = "Cerrar pestaña/buffer" })
    end },
  -- resaltado de sintaxis (treesitter rama main: compatible con nvim 0.11+/0.12)
  { "nvim-treesitter/nvim-treesitter", branch = "main", lazy = false, build = ":TSUpdate",
    config = function()
      local langs = {
        "lua", "vim", "vimdoc", "bash", "json", "yaml", "toml",
        "javascript", "typescript", "tsx", "html", "css", "python", "markdown", "markdown_inline",
      }
      -- SOLO descargar/compilar parsers en modo headless (el pre-warm de install.sh).
      -- En el panel editor EN VIVO (estrecho), los mensajes "Downloading tree-sitter-X..."
      -- de install() envuelven en varias lineas -> wait_return ("Press ENTER") -> congela
      -- el servidor y el RPC de yazi. En vivo solo activamos el resaltado de lo ya instalado.
      if #vim.api.nvim_list_uis() == 0 then
        pcall(function() require("nvim-treesitter").install(langs):wait(300000) end)
      end
      -- activa el resaltado nativo por buffer (no crashea si falta el parser)
      vim.api.nvim_create_autocmd("FileType", {
        callback = function() pcall(vim.treesitter.start) end,
      })
    end },
  -- guías de indentación
  { "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = {} },

  -- LSP: autocompletado, ir-a-definicion, diagnosticos
  { "saghen/blink.cmp", version = "1.*", opts = {
      keymap = { preset = "default" },        -- <C-space> abre, <C-y> acepta
      completion = { documentation = { auto_show = true } },
      signature = { enabled = true },
    } },
  { "mason-org/mason.nvim", opts = {} },
  { "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
    opts = {
      ensure_installed = { "lua_ls", "ts_ls", "jsonls", "html", "cssls", "bashls", "pyright" },
      automatic_enable = true,
    } },
  { "neovim/nvim-lspconfig" },
}, { ui = { border = "rounded" } })

-- capacidades de blink.cmp para todos los servidores LSP
pcall(function()
  vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
end)

-- atajos LSP al adjuntarse un servidor
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local b = ev.buf
    local map = function(k, fn) vim.keymap.set("n", k, fn, { buffer = b }) end
    map("gd", vim.lsp.buf.definition)
    map("gr", vim.lsp.buf.references)
    map("K", vim.lsp.buf.hover)
    map("<leader>rn", vim.lsp.buf.rename)
    map("<leader>ca", vim.lsp.buf.code_action)
    map("[d", function() vim.diagnostic.jump({ count = -1 }) end)
    map("]d", function() vim.diagnostic.jump({ count = 1 }) end)
  end,
})

-- :q y :wq cierran la PESTAÑA (buffer), no nvim entero.
-- (para salir de verdad usa :q! o :qa)
vim.api.nvim_create_user_command("WriteAndClose", function()
  vim.cmd.write(); vim.cmd("bdelete")
end, {})
vim.cmd([[cnoreabbrev <expr> q  (getcmdtype()==':' && getcmdline()=='q')  ? 'bd' : 'q']])
vim.cmd([[cnoreabbrev <expr> wq (getcmdtype()==':' && getcmdline()=='wq') ? 'WriteAndClose' : 'wq']])

-- aplicar el tema elegido
if THEME == "nord" then
  pcall(function() require("nord").set() end)
elseif THEME == "gruvbox" then
  pcall(function() require("gruvbox").setup({ contrast = "hard" }) end)
  pcall(vim.cmd.colorscheme, "gruvbox")
else
  pcall(vim.cmd.colorscheme, SEL.cs)
end
