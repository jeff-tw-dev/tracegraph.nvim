# tracegraph.nvim

Recursive call-trace tree for Neovim, built on LSP `callHierarchy`.

With the cursor on a function, open a side panel and expand
**caller-of-caller** (incoming) or **callee-of-callee** (outgoing) level by
level. Each expand issues exactly one more LSP request, so the tree is
naturally lazy — no upfront whole-project analysis.

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

## License

MIT
