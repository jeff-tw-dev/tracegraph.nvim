# tracegraph.nvim demo recording.
#
#   brew install vhs        # also pulls ttyd + ffmpeg
#   vhs demo/demo.tape      # run from the repository root
#
# Needs gopls on PATH (or a mason install — see demo/nvimrc.lua).
# The tree shape this script navigates is asserted by demo/verify.lua;
# run that first after changing the demo code, or the keystrokes below
# will land on the wrong rows.

Output demo/tracegraph.gif

Set Shell "bash"
Set FontSize 14
Set Width 1200
Set Height 720
Set Padding 12
Set Framerate 24
Set TypingSpeed 70ms

# Boot nvim and let gopls index the module off-camera.
Hide
Type "cd demo/shop"
Enter
Type "nvim -u ../nvimrc.lua internal/logging/log.go"
Enter
Sleep 20s
Type "/func Debugf"
Enter
Type "w"
Ctrl+L
Sleep 2s
Show

Sleep 2s

# Who calls this shared helper? One request, five callers,
# and ×2 where a caller logs from two different lines.
Type " ct"
Sleep 4s

# Walk up the chain — one LSP request per expand, nothing precomputed.
Down
Down
Down
Sleep 1s
Type "o"
Sleep 2s

Down
Type "o"
Sleep 2s

Down
Type "o"
Sleep 2s

Down
Type "o"
Sleep 3s

# Preview the call site without leaving the tree.
Down
Type "p"
Sleep 4s

# ...and jump to it.
Enter
Sleep 3s

Hide
Type ":qa!"
Enter
