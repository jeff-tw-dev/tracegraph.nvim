# demo

Everything needed to reproduce the README recording.

| File | What it is |
| --- | --- |
| `shop/` | A small Go order service — the codebase being traced |
| `nvimrc.lua` | Minimal Neovim config: this repo on the runtimepath, gopls, nothing else |
| `verify.lua` | Headless check that the call tree still has the shape the recording navigates |
| `demo.tape` | [VHS](https://github.com/charmbracelet/vhs) script that produces `tracegraph.gif` |

## Why `shop` looks the way it does

The layers are thin on purpose. `internal/logging.Debugf` is called from
five packages, so opening an incoming tree on it immediately shows the
fan-in, and one of those callers leads up a six-frame chain:

```
logging.Debugf <- pricing.Total <- service.PlaceOrder
               <- api.handleCheckout <- api.(*Server).Run <- main
```

Two other details are deliberate:

- `storage.(*Repo).Save` logs twice, so it renders as `Save ×2` — the
  call-site count.
- `catalog.(*Node).TotalCents` recurses, so tracing its **callees**
  (`<leader>cT` on it) shows the `↻` marker instead of descending
  forever.

`service.Repository` is an interface implemented by `storage.Repo`. Call
hierarchy follows concrete calls, so the demo chain deliberately avoids
crossing that boundary — see `../docs/TRADE-OFFS.md`.

## Run it

```sh
cd demo/shop
nvim -u ../nvimrc.lua internal/logging/log.go
```

Put the cursor on `Debugf`, press `<leader>ct`, then `o` your way up.

## Re-record

```sh
brew install vhs          # pulls ttyd + ffmpeg
vhs demo/demo.tape        # from the repository root
```

Re-run `verify.lua` first if `shop/` changed — the tape navigates by
cursor movement, so a different tree shape sends the keystrokes to the
wrong rows.
