return {
  {
    "LazyVim/LazyVim",
    init = function()
      vim.opt.mouse = "a"
      vim.opt.confirm = true
      vim.opt.exrc = false
      vim.opt.modeline = false
    end,
    keys = function()
      local settings = function()
        vim.ui.select({ "Configuration files", "Plugins", "Extra features", "Health check" },
          { prompt = "Editor settings" }, function(choice)
            if choice == "Configuration files" then
              Snacks.picker.files({ cwd = vim.fn.stdpath("config") })
            elseif choice == "Plugins" then
              vim.cmd("Lazy")
            elseif choice == "Extra features" then
              vim.cmd("LazyExtras")
            elseif choice == "Health check" then
              vim.cmd("LazyHealth")
            end
          end)
      end
      local help = function()
        vim.cmd("stopinsert")
        Snacks.win({
          text = "Click a file or press i to type. Esc returns to navigation.\n\nCtrl S  Save file\nCtrl Q  Quit with an unsaved changes prompt\nCtrl P  Find project file\nCtrl F  Search current file\nF2      Project explorer\nF3      Search project\nF4      Editor settings\n\nSpace   Show available commands in navigation mode\n:Settings  Open editor settings\n\nConfiguration files use Lua. Plugins and extra features use native LazyVim menus.\nPress q or Esc to close this help.",
          title = "OS editor help",
          enter = true,
          width = 0.8,
          height = 0.6,
          wo = { wrap = true },
          keys = { q = "close", ["<Esc>"] = "close" },
        })
      end
      vim.api.nvim_create_user_command("Settings", settings, { desc = "Editor settings", force = true })
      return {
        { "<C-s>", "<Cmd>update<CR>", mode = { "n", "i", "v" }, desc = "Save file" },
        { "<C-q>", "<Cmd>confirm qall<CR>", mode = { "n", "i", "v" }, desc = "Quit safely" },
        { "<C-p>", function() Snacks.picker.files() end, mode = { "n", "i" }, desc = "Find project file" },
        { "<C-f>", function() Snacks.picker.lines() end, mode = { "n", "i" }, desc = "Search current file" },
        { "<F1>", help, mode = { "n", "i" }, desc = "Simple editor help" },
        { "<F2>", function() Snacks.explorer() end, mode = { "n", "i" }, desc = "Project explorer" },
        { "<F3>", function() Snacks.picker.grep() end, mode = { "n", "i" }, desc = "Search project" },
        { "<F4>", settings, mode = { "n", "i" }, desc = "Editor settings" },
      }
    end,
  },
}
