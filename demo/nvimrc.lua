-- Minimal Neovim config for the demo recording and the verification run.
-- Loads tracegraph straight from this repo, plus gopls — nothing else, so
-- what you see in the GIF is the plugin and not somebody's dotfiles.
--
--   nvim -u demo/nvimrc.lua demo/shop/internal/logging/log.go
local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(repo)

vim.g.mapleader = " "

vim.o.termguicolors = true
vim.o.number = true
vim.o.signcolumn = "no"
vim.o.showmode = false
vim.o.ruler = false
vim.o.laststatus = 0
vim.o.swapfile = false
vim.o.updatetime = 200
vim.cmd.colorscheme("habamax")

-- 62 rather than the default 56 so the panel's key-hint header fits
-- without truncating `q:quit` on camera.
require("tracegraph").setup({
  panel = { width = 62 },
})

vim.keymap.set("n", "<leader>ct", function()
  require("tracegraph").open("incoming")
end, { desc = "Trace callers (recursive tree)" })
vim.keymap.set("n", "<leader>cT", function()
  require("tracegraph").open("outgoing")
end, { desc = "Trace callees (recursive tree)" })

-- gopls: prefer one on PATH, fall back to a mason install
local function gopls_cmd()
  if vim.fn.executable("gopls") == 1 then
    return { "gopls" }
  end
  local mason = vim.fn.stdpath("data") .. "/mason/bin/gopls"
  if vim.fn.executable(mason) == 1 then
    return { mason }
  end
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "go",
  callback = function(args)
    local cmd = gopls_cmd()
    if not cmd then
      vim.notify("demo: gopls not found", vim.log.levels.ERROR)
      return
    end
    vim.lsp.start({
      name = "gopls",
      cmd = cmd,
      root_dir = vim.fs.root(args.buf, { "go.mod" }),
    })
  end,
})
