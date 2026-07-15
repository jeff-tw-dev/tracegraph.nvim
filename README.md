# tracegraph.nvim

Recursive call-trace tree for Neovim, built on LSP `callHierarchy`.

With the cursor on a function, open a side panel and walk the call chain
in either direction — who calls the callers (incoming), or what the
callees call in turn (outgoing). Each expand issues exactly one more LSP
request, so the tree is naturally lazy — no upfront whole-project
analysis, no LSP handler hijacking, and recursion is detected and marked
instead of looping.

```
 Incoming: handle_request (callers)
 o:expand <CR>:call site gd:def p:preview s:direction q:quit
  handle_request  src/server.lua:42
     dispatch ×2  src/router.lua:88
       main  src/init.lua:12
    ↻ handle_request  src/server.lua:42
    · on_timer  src/poll.lua:30
```

- `×N` — the caller/callee references the function at N call sites
- `↻` — recursion (node already appears in its own ancestor chain)
- `·` — leaf (no further callers/callees)

## Requirements

- Neovim ≥ 0.10
- An LSP server that supports `textDocument/prepareCallHierarchy`
  (gopls, rust-analyzer, clangd, lua_ls, tsserver/vtsls, pyright, ...)

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "jeff-tw-dev/tracegraph.nvim",
  keys = {
    { "<leader>ct", function() require("tracegraph").open("incoming") end, desc = "Trace callers (recursive tree)" },
    { "<leader>cT", function() require("tracegraph").open("outgoing") end, desc = "Trace callees (recursive tree)" },
  },
  opts = {},
}
```

## Usage

Put the cursor on a function/method name, then:

- `require("tracegraph").open("incoming")` — who calls this? (recursively)
- `require("tracegraph").open("outgoing")` — what does this call? (recursively)
- `:Tracegraph incoming` / `:Tracegraph outgoing` — same via command

### Panel keys (defaults)

| Key         | Action                                        |
| ----------- | --------------------------------------------- |
| `o` / `<Tab>` | Expand / collapse node (lazy LSP request)   |
| `<CR>`      | Jump to the call site                         |
| `gd`        | Jump to the definition                        |
| `p`         | Preview the call site in a float              |
| `s`         | Switch direction (incoming ⇄ outgoing)        |
| `q`         | Close the panel                               |

## Configuration

`setup()` is optional — every field below is a default, and you only pass
what you want to change (tables are deep-merged):

```lua
require("tracegraph").setup({
  panel = {
    width = 56,          -- panel width in columns
    position = "right",  -- which side the panel opens on: "right" | "left"
  },
  preview = {
    context = 7,         -- source lines above/below the call site
    max_width = 100,     -- upper bound on the float's width
    border = "rounded",  -- border style of the float
  },
  keys = {               -- panel-local keymaps; a key or a list of keys
    expand = { "o", "<Tab>" },
    jump = "<CR>",
    definition = "gd",
    preview = "p",
    switch = "s",
    close = "q",
  },
  icons = {
    loading = "…",       -- LSP request in flight
    recursive = "↻",     -- node already appears in its ancestor chain
    leaf = "·",          -- no further callers/callees
    expanded = "",
    collapsed = "",
  },
})
```

### Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `panel.width` | number | `56` | Width of the tree panel in columns. The panel is `winfixwidth`, so it keeps this width across layout changes. |
| `panel.position` | string | `"right"` | `"right"` opens the panel as a `botright vsplit`, `"left"` as a `topleft vsplit`. |
| `preview.context` | number | `7` | Lines of source shown above and below the call site in the `p` preview float — its height is `2 * context + 1` (clamped at file boundaries). |
| `preview.max_width` | number | `100` | The float's width is the editor width minus margins, but never more than this. |
| `preview.border` | any | `"rounded"` | Passed straight to `nvim_open_win()` — `"single"`, `"double"`, `"none"`, a char array, ... |
| `keys.expand` | key(s) | `{ "o", "<Tab>" }` | Expand/collapse the node under the cursor. Expanding an unvisited node issues one LSP request. |
| `keys.jump` | key(s) | `"<CR>"` | Jump to the call site in the previous window (the root has no call site, so it jumps to the definition). |
| `keys.definition` | key(s) | `"gd"` | Jump to the node's definition. |
| `keys.preview` | key(s) | `"p"` | Open the call-site preview float; it closes on cursor move. |
| `keys.switch` | key(s) | `"s"` | Reopen the tree in the opposite direction (incoming ⇄ outgoing) for the same root. |
| `keys.close` | key(s) | `"q"` | Close the panel. |
| `icons.*` | string | see above | Node state markers rendered in the tree. The first key of each `keys` entry is what the panel's help header displays. |

Every `keys` value accepts either a single key (`"q"`) or a list of keys
(`{ "q", "<Esc>" }`) — each one is mapped.

## Comparison with alternatives

All of these build on the same LSP `callHierarchy` protocol and support
recursive expansion; they differ in dependencies, how they talk to the LSP,
and how much they bring along.

|  | tracegraph.nvim | [litee-calltree.nvim](https://github.com/ldelossa/litee-calltree.nvim) | [calltree.nvim](https://github.com/wilriker/calltree.nvim) | [telescope-hierarchy.nvim](https://github.com/jmacadie/telescope-hierarchy.nvim) |
| --- | --- | --- | --- | --- |
| Dependencies | none | litee.nvim framework | none | telescope.nvim + plenary |
| UI | side panel | litee panel (shared with other litee plugins) | side panel + document outline | Telescope picker |
| LSP integration | direct `client:request` calls | hijacks the global `callHierarchy` handlers | hijacks the global handlers | direct requests |
| Invoked via | `:Tracegraph` / lua API | `vim.lsp.buf.incoming_calls()` | `vim.lsp.buf.incoming_calls()` | `:Telescope hierarchy` |
| Lazy recursive expand | ✓ (one request per expand) | ✓ | ✓ | ✓ (plus multi-level `E`) |
| Switch direction in-session | ✓ (`s`) | ✓ (`S`) | ✓ (`s`) | ✓ (`s`) |
| Recursion (cycle) marking | ✓ (`↻`, blocks infinite descent) | — | — | — |
| Call-site count (`×N`) | ✓ | — | — | — |
| Inline preview | ✓ (float, `p`) | LSP hover (`i`) | LSP hover (`i`) | ✓ (Telescope previewer) |
| Scope | one file, tree only | IDE-style suite | tree + symbol outline | picker, experimental type hierarchy |

Reasons to pick one of the others: **litee-calltree** if you want a
cohesive multi-panel IDE layer (calltree + symboltree + bookmarks) that
plugs into `vim.lsp.buf.*` transparently; **telescope-hierarchy** if you
live in Telescope and prefer a transient picker over a persistent panel.

Reasons to pick tracegraph: zero dependencies, no global LSP handler
hijacking (your `vim.lsp.buf.incoming_calls()` stays untouched), recursion
detection, and a codebase small enough to read in one sitting.

Built-in `vim.lsp.buf.incoming_calls()` and Telescope's
`lsp_incoming_calls` remain the no-plugin baseline — single level only, no
recursive expansion.

## License

MIT
