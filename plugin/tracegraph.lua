if vim.g.loaded_tracegraph then
  return
end
vim.g.loaded_tracegraph = 1

vim.api.nvim_create_user_command("Tracegraph", function(opts)
  local direction = opts.args ~= "" and opts.args or "incoming"
  if direction ~= "incoming" and direction ~= "outgoing" then
    vim.notify("tracegraph: expected 'incoming' or 'outgoing'", vim.log.levels.WARN)
    return
  end
  require("tracegraph").open(direction)
end, {
  nargs = "?",
  complete = function()
    return { "incoming", "outgoing" }
  end,
  desc = "Open recursive call-trace tree (incoming|outgoing)",
})
