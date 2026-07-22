vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt
opt.number = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.termguicolors = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.splitbelow = true
opt.splitright = true
opt.ignorecase = true
opt.smartcase = true
opt.updatetime = 250
opt.timeoutlen = 400
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.completeopt = { "menu", "menuone", "noselect" }
opt.background = "dark"
opt.undofile = true
opt.swapfile = true
opt.showmode = false

local function setup_wsl_clipboard()
  local is_wsl = false
  local f = io.open("/proc/version", "r")
  if f then
    local content = f:read("*all")
    f:close()
    if content:lower():find("microsoft") or content:lower():find("wsl") then
      is_wsl = true
    end
  end
  if is_wsl and vim.fn.executable("clip.exe") == 1 and vim.fn.executable("powershell.exe") == 1 then
    vim.g.clipboard = {
      name = "WSL",
      copy = {
        ["+"] = "clip.exe",
        ["*"] = "clip.exe",
      },
      paste = {
        ["+"] = "powershell.exe -c Get-Clipboard -Raw",
        ["*"] = "powershell.exe -c Get-Clipboard -Raw",
      },
      cache_enabled = 0,
    }
  end
end

setup_wsl_clipboard()
