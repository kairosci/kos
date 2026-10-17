local MenuPolicy = {}
MenuPolicy.__index = MenuPolicy
function MenuPolicy.new(source)
    return setmetatable({ text = source }, MenuPolicy)
end
function MenuPolicy.read(path)
    local file = assert(io.open(path, "r"))
    local text = file:read("*a")
    file:close()
    return text
end
function MenuPolicy:replace_once(source, target)
    local first, last = self.text:find(source, 1, true)
    assert(first and not self.text:find(source, last + 1, true), "Unsupported menu structure: " .. source)
    self.text = self.text:sub(1, first - 1) .. target .. self.text:sub(last + 1)
end
function MenuPolicy:apply_width()
    self:replace_once(
        "Style.space(520) : Style.space(300)",
        "Style.space(root.sessionPolicy ? root.sessionPolicy.menu.width : 0) : Style.space(root.sessionPolicy ? root.sessionPolicy.menu.width : 0)"
    )
end
function MenuPolicy:apply_paths_qml()
    self:replace_once(
        "readonly property var appLibrary: root.shell ? root.shell.appLibrary : null",
        "readonly property var appLibrary: appCatalog"
    )
    self:replace_once(
        'property string defaultMenuPath: omarchyPath + "/default/omarchy/omarchy-menu.jsonc"',
        'property string defaultMenuPath: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/os/session/data/menu.json"'
    )
    self:replace_once(
        'property string userMenuPath: Quickshell.env("HOME") + "/.config/omarchy/extensions/omarchy-menu.jsonc"',
        'property string userMenuPath: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/os/extensions/os-menu.json"'
    )
end
function MenuPolicy:apply_dialog()
    self:replace_once("ConfirmDialog {", "ControlConfirmDialog {")
    self:replace_once("text: row.label", 'text: row.kind === "app" ? row.label + " >" : SessionI18n.text(row.label)')
end
function MenuPolicy:apply_order()
    self:replace_once(
        "    for (var k = 0; k < rows.length; k++) displayModel.append(rows[k])",
        "    root.sortMenuRows(rows)\n    for (var k = 0; k < rows.length; k++) displayModel.append(rows[k])"
    )
end
function MenuPolicy:finish(support_path)
    self:apply_paths_qml()
    self:apply_width()
    self:apply_dialog()
    self:apply_order()
    local ending = assert(self.text:find("}%s*$"))
    self.text = self.text:sub(1, ending - 1)
        .. MenuPolicy.read(assert(support_path))
        .. "\n  AppCatalog { id: appCatalog; policy: root.sessionPolicy }\n"
        .. self.text:sub(ending)
    return self.text
end
local policy = MenuPolicy.new(MenuPolicy.read(assert(arg[1])))
io.write(policy:finish(assert(arg[2])))
