#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly MISE="${MISE:-$HOME/.local/bin/mise}"

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/home/.config"
cp -a "$ROOT_DIR/home/dot_config/nvim" "$test_dir/home/.config/nvim"

export HOME="$test_dir/home"
export XDG_CACHE_HOME="$test_dir/cache"
export XDG_DATA_HOME="$test_dir/data"
export XDG_STATE_HOME="$test_dir/state"
export MISE_CONFIG_FILE="$ROOT_DIR/provisioning/mise/config.toml"
export MISE_DATA_DIR="${MISE_DATA_DIR:-$test_dir/mise-data}"
export MISE_CACHE_DIR="${MISE_CACHE_DIR:-$test_dir/mise-cache}"
export MISE_STATE_DIR="${MISE_STATE_DIR:-$test_dir/mise-state}"
export MISE_LOCKED=1
# Trust all mise configs in this isolated HOME so the smoke test does not
# prompt or fail on the trust mechanism.
export MISE_TRUSTED_CONFIG_PATHS="/"

"$MISE" exec neovim -- nvim --headless "+Lazy! sync" +qa
test -d "$XDG_DATA_HOME/nvim/lazy/lazy.nvim"

# Mason LSP servers are installed even in an empty state.
cat >"$test_dir/verify-mason.lua" <<'EOF'
local registry = require("mason-registry")
local required = {
  "lua-language-server",
  "typescript-language-server",
  "json-lsp",
  "bash-language-server",
}
for _, name in ipairs(required) do
  local pkg = registry.get_package(name)
  if not pkg:is_installed() and not pkg:is_installing() then
    pkg:install()
  end
end
local ok = vim.wait(120000, function()
  for _, name in ipairs(required) do
    local pkg = registry.get_package(name)
    if not pkg:is_installed() or pkg:is_installing() then
      return false
    end
  end
  return true
end, 500)
if not ok then
  print("Timeout waiting for Mason LSP servers")
  vim.cmd("cq!")
end
print("Mason LSP servers verified")
EOF
"$MISE" exec neovim -- nvim --headless -c "luafile $test_dir/verify-mason.lua" -c 'qa'

# Treesitter parsers are installed even in an empty state.
"$MISE" exec neovim -- nvim --headless -c 'TSInstallSync! bash json lua markdown markdown_inline query vim vimdoc javascript typescript tsx yaml toml' -c 'qa'
for parser in bash json lua markdown markdown_inline query vim vimdoc javascript typescript tsx yaml toml; do
  test -f "$XDG_DATA_HOME/nvim/lazy/nvim-treesitter/parser/$parser.so"
done

# Verify Neovim options.
cat >"$test_dir/verify-options.lua" <<'EOF'
local opt = vim.opt
assert(opt.background:get() == "dark", "background must be dark")
assert(opt.undofile:get() == true, "undofile must be true")
assert(opt.swapfile:get() == true, "swapfile must be true")
assert(opt.showmode:get() == false, "showmode must be false")
assert(opt.timeoutlen:get() == 400, "timeoutlen must be 400")
print("Options verified")
EOF
"$MISE" exec neovim -- nvim --headless -c "luafile $test_dir/verify-options.lua" -c 'qa'

# Verify global keymaps.
cat >"$test_dir/verify-keymaps.lua" <<'EOF'
local function assert_map(lhs, mode, expected_rhs)
  local info = vim.fn.maparg(lhs, mode, false, true)
  if vim.tbl_isempty(info) then
    print("MISSING keymap: " .. lhs)
    return false
  end
  if expected_rhs ~= nil and info.rhs ~= expected_rhs then
    print("MISMATCH keymap: " .. lhs .. " (got: " .. tostring(info.rhs) .. ", expected: " .. expected_rhs .. ")")
    return false
  end
  if expected_rhs == nil and info.callback == nil and info.rhs == "" then
    print("EMPTY keymap: " .. lhs)
    return false
  end
  return true
end
local expected = {
  { "<leader>w", "n", "<cmd>write<cr>" },
  { "<leader>m", "n", "<cmd>Mason<cr>" },
  { "<leader>e", "n", "<cmd>NvimTreeToggle<cr>" },
  { "<leader>E", "n", "<cmd>NvimTreeFocus<cr>" },
  { "<leader>f", "n", "<cmd>NvimTreeFindFile<cr>" },
  { "<S-h>", "n", "<cmd>BufferLineCyclePrev<cr>" },
  { "<S-l>", "n", "<cmd>BufferLineCycleNext<cr>" },
  { "<leader>bp", "n", "<cmd>BufferLinePick<cr>" },
  { "<leader>bc", "n", "<cmd>bdelete<cr>" },
  { "<leader>bo", "n", "<cmd>BufferLineCloseOthers<cr>" },
  { "[d", "n" },
  { "]d", "n" },
  { "<leader>q", "n" },
}
local fail = false
for _, spec in ipairs(expected) do
  if not assert_map(spec[1], spec[2], spec[3]) then
    fail = true
  end
end
for i = 1, 9 do
  local lhs = "<leader>" .. i
  if not assert_map(lhs, "n", "<cmd>BufferLineGoToBuffer " .. i .. "<cr>") then
    fail = true
  end
end
if not vim.tbl_isempty(vim.fn.maparg("<leader>y", "v", false, true)) then
  print("UNEXPECTED keymap: <leader>y in visual mode")
  fail = true
end
if fail then
  vim.cmd("cq!")
else
  print("Keymaps verified")
end
EOF
"$MISE" exec neovim -- nvim --headless -c "luafile $test_dir/verify-keymaps.lua" -c 'qa'

# Verify plugins load without error.
cat >"$test_dir/verify-plugins.lua" <<'EOF'
local fail = false
local ok, err = pcall(require, "bufferline")
if not ok then
  print("bufferline failed to load: " .. tostring(err))
  fail = true
end
ok, err = pcall(require, "scrollbar")
if not ok then
  print("scrollbar failed to load: " .. tostring(err))
  fail = true
end
ok, err = pcall(require, "gitsigns")
if not ok then
  print("gitsigns failed to load: " .. tostring(err))
  fail = true
end
if fail then
  vim.cmd("cq!")
else
  print("Plugins verified")
end
EOF
"$MISE" exec neovim -- nvim --headless -c "luafile $test_dir/verify-plugins.lua" -c 'qa'

# Verify clipboard configuration.
cat >"$test_dir/verify-clipboard.lua" <<'EOF'
local clipboard_val = vim.opt.clipboard:get()
local ok = false
if type(clipboard_val) == "string" then
  ok = clipboard_val:find("unnamedplus") ~= nil
elseif type(clipboard_val) == "table" then
  for _, v in ipairs(clipboard_val) do
    if v == "unnamedplus" then ok = true break end
  end
end
if not ok then
  print("Clipboard check failed, value: " .. vim.inspect(clipboard_val))
  vim.cmd("cq!")
else
  print("Clipboard verified")
end
EOF
"$MISE" exec neovim -- nvim --headless -c "luafile $test_dir/verify-clipboard.lua" -c 'qa'

"$MISE" exec neovim -- nvim --headless "+checkhealth vim.deprecated" +qa

printf 'Neovim empty-state smoke test passed.\n'
