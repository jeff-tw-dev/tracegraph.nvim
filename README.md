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

Defaults shown; all fields optional:

```lua
require("tracegraph").setup({
  width = 56, -- side panel width
  keys = {    -- panel-local keymaps; a key or a list of keys
    expand = { "o", "<Tab>" },
    jump = "<CR>",
    definition = "gd",
    preview = "p",
    switch = "s",
    close = "q",
  },
  icons = {
    loading = "…",
    recursive = "↻",
    leaf = "·",
    expanded = "",
    collapsed = "",
  },
})
```

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
