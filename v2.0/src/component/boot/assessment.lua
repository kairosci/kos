local File = require("core.file")
local Json = require("core.json")
local Publisher = require("core.publisher")
local Menu = require("component.boot.menu")
local Assessment = {}
Assessment.__index = Assessment

function Assessment.new(root, process, policy, boot, format)
    return setmetatable({root=root, process=process, policy=policy, boot=boot, menu=Menu.new(process, format), publisher=Publisher.new(process)}, Assessment)
end

function Assessment:read_optional(path)
    local file, failure, code = io.open(path, "rb")
    if not file then assert(code == 2, failure); return nil end
    local content = assert(file:read("a")); assert(file:close()); return content
end

function Assessment:record()
    assert(self.process:run("identity"):match("^0%s*$"), "root_required")
    local policy, boot = self.policy, self.boot
    local contents = {}
    for _, observation in ipairs(policy.observations) do
        local content = self.process:run(observation.command)
        if observation.json then Json.decode(content) end
        contents[observation.file] = content
    end
    contents["current-cmdline.txt"] = File.read(policy.cmdline)
    for _, path in ipairs(policy.configuration) do
        local content = self:read_optional(path)
        if content then contents[assert(path:match("([^/]+)$"))] = content end
    end
    local presets = self.process:run("bootPresets", {policy.presets, "-maxdepth", "1", "-type", "f", "-name", policy.presetPattern, "-print0"})
    for path in presets:gmatch("[^%z]+") do contents[assert(path:match("([^/]+)$"))] = File.read(path) end
    local inventory = File.read(boot.esp .. "/" .. policy.inventory)
    local entries = self.menu:verify(self.menu:read(inventory), boot.esp)
    contents[policy.inventory] = inventory
    contents["verified-menu.json"] = Json.encode({entries=entries, trialBootVerified=false})
    self.process:run("directory", {policy.destination})
    self.process:run("permissions", {policy.directoryMode, policy.destination})
    for name, content in pairs(contents) do self.publisher:publish(policy.destination .. "/" .. name, content, policy.fileMode) end
    return {entries=#entries, trialBootVerified=false}
end

return Assessment
