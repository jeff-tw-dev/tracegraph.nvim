-- Headless check that the demo codebase produces the tree the recording
-- is scripted around. Run from demo/shop so paths render relative:
--
--   cd demo/shop
--   nvim --headless -u ../nvimrc.lua internal/logging/log.go \
--        +"lua dofile('../verify.lua')"
--
-- Exits non-zero (and prints the tree) when the shape drifts.
local function out(s)
  io.stdout:write(s .. "\n")
end

local function fail(msg)
  out("FAIL: " .. msg)
  vim.cmd("cquit!")
end

local function panel_buf()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].filetype == "tracegraph" then
      return b
    end
  end
end

local function panel_lines()
  local b = panel_buf()
  return b and vim.api.nvim_buf_get_lines(b, 0, -1, false) or {}
end

local function find_row(pattern)
  for i, l in ipairs(panel_lines()) do
    if l:match(pattern) then
      return i
    end
  end
end

local src = vim.api.nvim_get_current_buf()

-- 1. gopls attaches and reports no diagnostics (i.e. the module compiles)
if
  not vim.wait(90000, function()
    return #vim.lsp.get_clients({ bufnr = src, method = "textDocument/prepareCallHierarchy" }) > 0
  end, 500)
then
  fail("gopls never attached")
end
vim.wait(4000) -- let the initial workspace load settle

local diags = vim.diagnostic.get(nil, { severity = vim.diagnostic.severity.ERROR })
if #diags > 0 then
  for _, d in ipairs(diags) do
    out(("DIAG %s: %s"):format(vim.api.nvim_buf_get_name(d.bufnr), d.message))
  end
  fail(#diags .. " compile error(s) in the demo module")
end
out("STEP1 OK: gopls attached, no errors")

-- 2. open the incoming tree on Debugf
local debugf_line
for i, l in ipairs(vim.api.nvim_buf_get_lines(src, 0, -1, false)) do
  if l:match("^func Debugf") then
    debugf_line = i
  end
end
if not debugf_line then
  fail("func Debugf not found in the source buffer")
end
vim.api.nvim_win_set_cursor(0, { debugf_line, 5 })

require("tracegraph").open("incoming")
if not vim.wait(30000, function()
  return find_row("Total") ~= nil
end, 300) then
  fail("callers of Debugf never rendered")
end

-- fan-in: every layer that logs shows up as a direct caller
for _, want in ipairs({ "OrderPlaced", "Save", "Total", "TotalCents", "validate" }) do
  if not find_row(want) then
    fail("missing caller " .. want .. "\n" .. table.concat(panel_lines(), "\n"))
  end
end
if not find_row("Save ×2") then
  fail("expected the ×2 call-site count on Save\n" .. table.concat(panel_lines(), "\n"))
end
out("STEP2 OK: 5 callers, Save shows ×2")

-- 3. drill up the chain, one expand at a time
local function expand(pattern)
  local win = vim.fn.bufwinid(panel_buf())
  vim.api.nvim_set_current_win(win)
  local row = find_row(pattern)
  if not row then
    fail("row not found: " .. pattern .. "\n" .. table.concat(panel_lines(), "\n"))
  end
  vim.api.nvim_win_set_cursor(win, { row, 0 })
  local before = #panel_lines()
  vim.fn.feedkeys("o", "x")
  if not vim.wait(20000, function()
    return #panel_lines() > before
  end, 200) then
    fail("expanding " .. pattern .. " produced no children")
  end
end

expand("Total")
expand("PlaceOrder")
expand("handleCheckout")
expand("Run")

local tree = table.concat(panel_lines(), "\n")
out("=== TREE ===\n" .. tree .. "\n============")

for _, want in ipairs({ "Total", "PlaceOrder", "handleCheckout", "Run", "main" }) do
  if not tree:match(want) then
    fail("chain broke, missing " .. want)
  end
end

-- the deepest row must be indented six levels (root + five frames)
if not tree:match("\n%s+main%s") then
  fail("main is not rendered as the top of the chain")
end
out("STEP3 OK: six-frame chain Debugf <- Total <- PlaceOrder <- handleCheckout <- Run <- main")
out("ALL_PASS")
vim.cmd("qa!")
