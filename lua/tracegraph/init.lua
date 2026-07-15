-- tracegraph.nvim — recursive call-trace tree.
-- With the cursor on a function, open a side panel and expand
-- caller-of-caller (incoming) or callee-of-callee (outgoing) level by
-- level, based on LSP callHierarchy. Each expand issues one more LSP
-- request, so the tree is naturally lazy.
local M = {}

local ns = vim.api.nvim_create_namespace("tracegraph")

M.config = {
  panel = {
    width = 56, -- panel width (columns)
    position = "right", -- "right" | "left"
  },
  preview = {
    context = 7, -- source lines shown above/below the call site (height = 2*context + 1)
    max_width = 100, -- float never grows wider than this
    border = "rounded", -- any value accepted by nvim_open_win() border
  },
  -- panel-local keymaps; each value is a key or a list of keys
  keys = {
    expand = { "o", "<Tab>" }, -- expand/collapse node
    jump = "<CR>", -- jump to call site
    definition = "gd", -- jump to definition
    preview = "p", -- preview call site in a float
    switch = "s", -- switch incoming/outgoing
    close = "q", -- close panel
  },
  icons = {
    loading = "…",
    recursive = "↻",
    leaf = "·",
    expanded = "",
    collapsed = "",
  },
}

function M.setup(opts)
  opts = opts or {}
  if opts.width then -- pre-0.2 top-level `width`
    opts.panel = vim.tbl_extend("keep", opts.panel or {}, { width = opts.width })
    opts.width = nil
  end
  M.config = vim.tbl_deep_extend("force", M.config, opts)
end

-- Single panel state (only one open at a time)
-- node = { item, children=nil|{}, expanded, depth, parent,
--          call_ranges = ranges of the call sites,
--          call_uri = file containing the call sites,
--          recursive = duplicate of a node in the ancestor chain, loading }
local state = nil

local HEADER_LINES = 2

---------------------------------------------------------------------------
-- LSP requests
---------------------------------------------------------------------------

local function get_client(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/prepareCallHierarchy" })
  return clients[1]
end

local function node_key(item)
  return ("%s:%d:%s"):format(item.uri, item.selectionRange.start.line, item.name)
end

local function is_ancestor(node, key)
  local cur = node.parent
  while cur do
    if node_key(cur.item) == key then
      return true
    end
    cur = cur.parent
  end
  return false
end

-- Request the next level for `node`; fills node.children and re-renders
local function request_children(node, on_done)
  local st = state
  local method = st.direction == "incoming" and "callHierarchy/incomingCalls" or "callHierarchy/outgoingCalls"
  node.loading = true
  st.client:request(method, { item = node.item }, function(err, result)
    node.loading = false
    node.children = {}
    if err then
      vim.notify("tracegraph: " .. err.message, vim.log.levels.WARN)
    end
    for _, call in ipairs(result or {}) do
      -- incoming: call.from = the caller; fromRanges are call sites in the caller's file
      -- outgoing: call.to = the callee; fromRanges are call sites in the CURRENT node's file
      local item = call.from or call.to
      local child = {
        item = item,
        parent = node,
        depth = node.depth + 1,
        expanded = false,
        call_ranges = call.fromRanges,
        call_uri = call.from and item.uri or node.item.uri,
        recursive = node_key(item) == node_key(node.item) or is_ancestor(node, node_key(item)),
      }
      table.insert(node.children, child)
    end
    table.sort(node.children, function(a, b)
      return a.item.name < b.item.name
    end)
    if on_done then
      on_done()
    end
  end, st.source_buf)
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------

local function short_path(uri)
  local path = vim.uri_to_fname(uri)
  return vim.fn.fnamemodify(path, ":~:.")
end

local function node_icon(node)
  local icons = M.config.icons
  if node.loading then
    return icons.loading
  elseif node.recursive then
    return icons.recursive
  elseif node.children and #node.children == 0 then
    return icons.leaf
  elseif node.expanded then
    return icons.expanded
  else
    return icons.collapsed
  end
end

local function first_key(v)
  return type(v) == "table" and v[1] or v
end

local function render()
  local st = state
  if not st or not vim.api.nvim_buf_is_valid(st.buf) then
    return
  end

  local lines, marks = {}, {}
  st.line_nodes = {}

  local keys = M.config.keys
  local arrow = st.direction == "incoming" and "callers" or "callees"
  lines[1] = (" %s: %s (%s)"):format(st.direction == "incoming" and "Incoming" or "Outgoing", st.root.item.name, arrow)
  lines[2] = (" %s:expand %s:call site %s:def %s:preview %s:direction %s:quit"):format(
    first_key(keys.expand),
    first_key(keys.jump),
    first_key(keys.definition),
    first_key(keys.preview),
    first_key(keys.switch),
    first_key(keys.close)
  )
  marks[#marks + 1] = { 0, 0, #lines[1], "Title" }
  marks[#marks + 1] = { 1, 0, #lines[2], "Comment" }

  local function walk(node)
    local icon = node_icon(node)
    local name = node.item.name
    local sites = ""
    if node.call_ranges and #node.call_ranges > 1 then
      sites = ("×%d"):format(#node.call_ranges)
    end
    local loc_range = (node.call_ranges and node.call_ranges[1]) or node.item.selectionRange
    local loc = ("%s:%d"):format(short_path(node.call_uri or node.item.uri), loc_range.start.line + 1)

    local indent = string.rep("  ", node.depth)
    local prefix = (" %s%s "):format(indent, icon)
    local line = prefix .. name .. (sites ~= "" and (" " .. sites) or "") .. "  " .. loc
    table.insert(lines, line)
    local row = #lines - 1
    st.line_nodes[#lines] = node

    marks[#marks + 1] = { row, 1, #prefix, "Special" }
    marks[#marks + 1] = { row, #prefix, #prefix + #name, node.recursive and "WarningMsg" or "Function" }
    marks[#marks + 1] = { row, #prefix + #name, #line, "Comment" }

    if node.expanded and node.children then
      for _, child in ipairs(node.children) do
        walk(child)
      end
    end
  end
  walk(st.root)

  vim.bo[st.buf].modifiable = true
  vim.api.nvim_buf_set_lines(st.buf, 0, -1, false, lines)
  vim.bo[st.buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(st.buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(st.buf, ns, m[1], m[2], { end_col = m[3], hl_group = m[4] })
  end
end

local function node_at_cursor()
  if not state then
    return nil
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  return state.line_nodes[lnum]
end

---------------------------------------------------------------------------
-- Panel actions
---------------------------------------------------------------------------

local function toggle_expand()
  local node = node_at_cursor()
  if not node then
    return
  end
  if node.recursive then
    vim.notify("tracegraph: recursive node (already in the ancestor chain)", vim.log.levels.INFO)
    return
  end
  if node.expanded then
    node.expanded = false
    render()
  elseif node.children then
    node.expanded = true
    render()
  else
    node.expanded = true
    render() -- draw the loading state first
    request_children(node, render)
  end
end

-- Pick a non-panel window to jump in; prefer the window active before the panel opened
local function target_window()
  local st = state
  if st.prev_win and vim.api.nvim_win_is_valid(st.prev_win) then
    return st.prev_win
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= st.win and vim.api.nvim_win_get_config(win).relative == "" then
      return win
    end
  end
  return nil
end

local function open_location(uri, range)
  local win = target_window()
  if not win then
    return
  end
  vim.api.nvim_set_current_win(win)
  local bufnr = vim.uri_to_bufnr(uri)
  vim.fn.bufload(bufnr)
  vim.bo[bufnr].buflisted = true
  vim.api.nvim_win_set_buf(win, bufnr)
  vim.api.nvim_win_set_cursor(win, { range.start.line + 1, range.start.character })
  vim.cmd("normal! zz")
end

-- Jump to the call site (the root has no call site, so jump to definition)
local function jump_to_callsite()
  local node = node_at_cursor()
  if not node then
    return
  end
  if node.call_ranges and #node.call_ranges > 0 then
    open_location(node.call_uri, node.call_ranges[1])
  else
    open_location(node.item.uri, node.item.selectionRange)
  end
end

local function jump_to_definition()
  local node = node_at_cursor()
  if node then
    open_location(node.item.uri, node.item.selectionRange)
  end
end

local function preview()
  local node = node_at_cursor()
  if not node then
    return
  end
  local uri = (node.call_ranges and node.call_uri) or node.item.uri
  local range = (node.call_ranges and node.call_ranges[1]) or node.item.selectionRange
  local bufnr = vim.uri_to_bufnr(uri)
  vim.fn.bufload(bufnr)

  local pv = M.config.preview
  local total = vim.api.nvim_buf_line_count(bufnr)
  local center = range.start.line
  local first = math.max(0, center - pv.context)
  local last = math.min(total, center + pv.context + 1)

  local float_buf = vim.api.nvim_create_buf(false, true)
  local src_lines = vim.api.nvim_buf_get_lines(bufnr, first, last, false)
  vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, src_lines)
  vim.bo[float_buf].filetype = vim.bo[bufnr].filetype
  vim.bo[float_buf].bufhidden = "wipe"

  local width = math.min(pv.max_width, math.max(40, vim.o.columns - 20))
  local float_win = vim.api.nvim_open_win(float_buf, false, {
    relative = "cursor",
    row = 1,
    col = 2,
    width = width,
    height = #src_lines,
    style = "minimal",
    border = pv.border,
    title = (" %s:%d "):format(short_path(uri), range.start.line + 1),
  })
  vim.api.nvim_buf_clear_namespace(float_buf, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(float_buf, ns, center - first, 0, {
    end_row = center - first + 1,
    hl_group = "Visual",
    hl_eol = true,
  })
  -- close on cursor move or leaving the panel
  vim.api.nvim_create_autocmd({ "CursorMoved", "BufLeave" }, {
    buffer = state.buf,
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(float_win) then
        vim.api.nvim_win_close(float_win, true)
      end
    end,
  })
end

function M.close()
  if state then
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_win_close(state.win, true)
    end
    state = nil
  end
end

local function switch_direction()
  if not state then
    return
  end
  local item = state.root.item
  local dir = state.direction == "incoming" and "outgoing" or "incoming"
  M.open_from_item(item, dir, state.client, state.source_buf)
end

---------------------------------------------------------------------------
-- Opening
---------------------------------------------------------------------------

local function set_keys(buf, lhs, rhs)
  local opts = { buffer = buf, nowait = true, silent = true }
  for _, key in ipairs(type(lhs) == "table" and lhs or { lhs }) do
    vim.keymap.set("n", key, rhs, opts)
  end
end

local function create_panel()
  local prev_win = vim.api.nvim_get_current_win()
  vim.cmd(M.config.panel.position == "left" and "topleft vsplit" or "botright vsplit")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(win, M.config.panel.width)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)

  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "tracegraph"
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].cursorline = true
  vim.wo[win].winfixwidth = true
  vim.wo[win].wrap = false

  local keys = M.config.keys
  set_keys(buf, keys.expand, toggle_expand)
  set_keys(buf, keys.jump, jump_to_callsite)
  set_keys(buf, keys.definition, jump_to_definition)
  set_keys(buf, keys.preview, preview)
  set_keys(buf, keys.switch, switch_direction)
  set_keys(buf, keys.close, M.close)

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      state = nil
    end,
  })
  return buf, win, prev_win
end

-- Open the panel from an existing CallHierarchyItem (reused when switching direction)
function M.open_from_item(item, direction, client, source_buf)
  local reuse_prev
  if state then
    reuse_prev = state.prev_win
    M.close()
  end
  local buf, win, prev_win = create_panel()
  state = {
    buf = buf,
    win = win,
    prev_win = reuse_prev or prev_win,
    direction = direction,
    client = client,
    source_buf = source_buf,
    line_nodes = {},
    root = { item = item, depth = 0, expanded = true },
  }
  render()
  request_children(state.root, render)
  -- put the cursor on the root node
  vim.api.nvim_win_set_cursor(win, { HEADER_LINES + 1, 0 })
end

-- Entry point: call with the cursor on a function/method
function M.open(direction)
  direction = direction or "incoming"
  local source_buf = vim.api.nvim_get_current_buf()
  local client = get_client(source_buf)
  if not client then
    vim.notify("tracegraph: no LSP client supporting call hierarchy", vim.log.levels.WARN)
    return
  end
  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  client:request("textDocument/prepareCallHierarchy", params, function(err, result)
    if err or not result or #result == 0 then
      vim.notify("tracegraph: no traceable function/method under cursor", vim.log.levels.WARN)
      return
    end
    M.open_from_item(result[1], direction, client, source_buf)
  end, source_buf)
end

return M
