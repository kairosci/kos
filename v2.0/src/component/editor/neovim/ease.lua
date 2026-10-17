local interface = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/os-editor.json"), "\n"))
local messages = interface.messages
local function settings()
    local labels = {}
    for _, item in ipairs(interface.menu) do labels[#labels + 1] = messages[item.label] end
    vim.ui.select(labels, {prompt=messages.settings}, function(choice)
        if not choice then return end
        for index, label in ipairs(labels) do
            if label == choice then
                local item = interface.menu[index]
                if item.command then vim.cmd(item.command)
                else Snacks.picker.files({cwd=vim.fn.stdpath("config")}) end
                return
            end
        end
    end)
end
local function help()
    vim.cmd(interface.stopInsert)
    local window = vim.deepcopy(interface.window)
    window.text, window.title = messages.help, messages.title
    Snacks.win(window)
end
local actions = {
    settings=settings, help=help,
    files=function() Snacks.picker.files() end,
    lines=function() Snacks.picker.lines() end,
    explorer=function() Snacks.explorer() end,
    grep=function() Snacks.picker.grep() end,
}
return {{
    interface.plugin,
    init=function() for key, value in pairs(interface.options) do vim.opt[key] = value end end,
    keys=function()
        vim.api.nvim_create_user_command(interface.command, settings, {desc=messages.settings, force=true})
        local keys = {}
        for _, binding in ipairs(interface.bindings) do
            keys[#keys + 1] = {binding.key, binding.command or assert(actions[binding.action]), mode=binding.mode, desc=messages[binding.description]}
        end
        return keys
    end,
}}
