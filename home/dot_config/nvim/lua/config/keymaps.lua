local map = vim.keymap.set

map("n", "<leader>w", "<cmd>write<cr>", { desc = "Save file" })
map("n", "<esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "Previous diagnostic" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Next diagnostic" })
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostic list" })
map("n", "<leader>m", "<cmd>Mason<cr>", { desc = "Open Mason" })
map("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "Toggle file tree" })
map("n", "<leader>E", "<cmd>NvimTreeFocus<cr>", { desc = "Focus file tree" })
map("n", "<leader>f", "<cmd>NvimTreeFindFile<cr>", { desc = "Reveal file in tree" })
map("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
map("n", "<leader>bp", "<cmd>BufferLinePick<cr>", { desc = "Buffer picker" })
map("n", "<leader>bc", "<cmd>BufferLinePickClose<cr>", { desc = "Close buffer" })
map("n", "<leader>bo", "<cmd>BufferLineCloseOthers<cr>", { desc = "Close other buffers" })
for i = 1, 9 do
  map("n", "<leader>" .. i, "<cmd>BufferLineGoToBuffer " .. i .. "<cr>", { desc = "Go to buffer " .. i })
end
