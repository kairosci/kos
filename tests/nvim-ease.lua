local selected, action, command, help
vim = {
  opt = {},
  fn = { stdpath = function(kind) assert(kind == "config"); return "/editor/config" end },
  ui = { select = function(items, opts, callback)
    assert(#items == 4 and opts.prompt == "Editor settings")
    callback(selected)
  end },
  api = { nvim_create_user_command = function(name, callback)
    assert(name == "Settings")
    command = callback
  end },
  cmd = function(name) action = name end,
}
Snacks = {
  picker = {
    files = function(opts) action = opts and opts.cwd or "files" end,
    lines = function() action = "lines" end,
    grep = function() action = "grep" end,
  },
  explorer = function() action = "explorer" end,
  win = function(opts) help = opts end,
}
local spec = dofile(arg[1])[1]
spec.init()
assert(vim.opt.mouse == "a" and vim.opt.confirm)
assert(vim.opt.exrc == false and vim.opt.modeline == false)
local keys = {}
for _, key in ipairs(spec.keys()) do keys[key[1]] = key[2] end
assert(keys["<C-s>"] == "<Cmd>update<CR>")
assert(keys["<C-q>"] == "<Cmd>confirm qall<CR>")
for key, expected in pairs({ ["<C-p>"] = "files", ["<C-f>"] = "lines", ["<F2>"] = "explorer", ["<F3>"] = "grep" }) do
  keys[key]()
  assert(action == expected)
end
for choice, expected in pairs({ ["Configuration files"] = "/editor/config", Plugins = "Lazy", ["Extra features"] = "LazyExtras", ["Health check"] = "LazyHealth" }) do
  selected = choice
  keys["<F4>"]()
  assert(action == expected)
  action = nil
  command()
  assert(action == expected)
end
selected, action = nil, nil
command()
assert(action == nil)
keys["<F1>"]()
assert(help.enter and help.wo.wrap and help.keys.q == "close" and help.keys["<Esc>"] == "close")
assert(help.text:find(":Settings", 1, true))
