local File = require("core.file")
local Bundle = require("core.bundle")
local Installer = {}
Installer.__index = Installer

function Installer.new(model)
    return setmetatable({ model = model }, Installer)
end

function Installer:apply()
    local model = self.model
    local policy, process = model.policy, model.process
    local bundle = Bundle.new(model.root, process, model.paths, policy)
    local main = model.paths:resolve("config", policy.main)
    local lines = {}
    for line in (File.read(main) .. "\n"):gmatch("([^\n]*)\n") do
        if line:match("^%s*(.-)%s*$") ~= policy.include then lines[#lines + 1] = line end
    end
    local content = table.concat(lines, "\n"):gsub("%s*$", "") .. "\n" .. policy.include .. "\n"
    local stage = process:run("temporary", { "-d" }):gsub("\n$", "")
    local generated = model:render(model:state())
    local ok, failure = pcall(function()
        local components = require("core.json").array({})
        for path in
            process
                :run("runtimeFiles", {
                    model.root .. "/" .. assert(policy.qml:match("^(.*)/[^/]+$")),
                    "-name",
                    "*.qml",
                    "-type",
                    "f",
                    "-print0",
                })
                :gmatch("[^%z]+")
        do
            components[#components + 1] = path
        end
        local manifest = stage .. "/components.json"
        model.publisher:publish(manifest, require("core.json").encode(components), policy.privateMode)
        local validation = process:run("settingsQml", {
            "OS_SETTINGS_COMPONENTS=" .. manifest,
            "QT_QPA_PLATFORM=offscreen",
            "timeout",
            "20",
            "quickshell",
            "--path",
            model.root .. "/" .. policy.validator,
        })
        assert(validation:find(policy.qmlValidationSuccess, 1, true), "settings_qml_validation_failed")
        process:run("copyTree", { model.paths:resolve("config", policy.configDirectory), stage .. "/hypr" })
        model.publisher:publish(stage .. "/" .. policy.generated, generated, policy.privateMode)
        model.publisher:publish(stage .. "/" .. policy.main, content, policy.privateMode)
        local result = process:run("settingsValidate", {
            "XDG_CONFIG_HOME=" .. stage,
            "OS_HYPR_CONFIG_ROOT=" .. stage .. "/hypr",
            "Hyprland",
            "--verify-config",
            "--config",
            stage .. "/" .. policy.main,
        })
        assert(result:find(policy.validationSuccess, 1, true), "settings_install_validation_failed")
        bundle:publish()
        model.publisher:publish(model.paths:resolve("config", policy.generated), generated, policy.privateMode)
        model.publisher:publish(main, content, policy.privateMode)
        model.publisher:publish(
            model.paths:resolve("home", ".local/" .. policy.launcher),
            File.read(model.root .. "/" .. policy.launcherSource),
            "755"
        )
        model.publisher:publish(
            model.paths:resolve("data", policy.desktop),
            File.read(model.root .. "/" .. policy.desktopSource),
            policy.mode
        )
        process:run("desktopDatabase", { model.paths:resolve("data", "applications") })
    end)
    process:run("removeDirectory", { stage })
    assert(ok, failure)
end

return Installer
