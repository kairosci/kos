local File = require("core.file")
local Json = require("core.json")
local Model = {}
Model.__index = Model

function Model.new(root, process, paths, publisher, policy, catalog)
    return setmetatable({root=root, process=process, paths=paths, publisher=publisher, policy=policy, catalog=catalog}, Model)
end

function Model:state()
    local path = self.paths:resolve("config", self.policy.state)
    local handle, failure, code = io.open(path, "rb")
    if not handle then assert(code == 2, failure); return {} end
    local content = assert(handle:read("a")); assert(handle:close())
    local state = Json.decode(content)
    assert(type(state) == "table" and state ~= Json.null and getmetatable(state) == nil, "invalid_settings_state")
    for key, value in pairs(state) do self:validate(key, value) end
    return state
end

function Model:validate(key, value)
    local option
    for _, entry in ipairs(self.policy.options) do if entry.key == key then option = entry; break end end
    assert(option, "unknown_setting")
    if option.kind == "boolean" then assert(type(value) == "boolean", "invalid_boolean_setting")
    elseif option.kind == "number" then
        assert(type(value) == "number" and value == value and value >= option.min and value <= option.max, "invalid_number_setting")
        if option.step == 1 then assert(value % 1 == 0, "integer_setting_required") end
    elseif option.kind == "string" then
        assert(type(value) == "string" and #value <= option.maximumLength and value:match(option.pattern), "invalid_string_setting")
    else error("unsupported_setting_kind") end
    return option
end

function Model:render(state)
    local tree = {}
    for key, value in pairs(state) do
        self:validate(key, value)
        local parent, parts = tree, {}
        for part in key:gmatch("[^:]+") do parts[#parts + 1] = part end
        for index = 1, #parts - 1 do parent[parts[index]] = parent[parts[index]] or {}; parent = parent[parts[index]] end
        parent[parts[#parts]] = value
    end
    local function emit(value)
        if type(value) == "string" then return string.format("%q", value) end
        if type(value) ~= "table" then return tostring(value) end
        local keys, output = {}, {}
        for key in pairs(value) do keys[#keys + 1] = key end
        table.sort(keys)
        for _, key in ipairs(keys) do output[#output + 1] = "[" .. string.format("%q", key) .. "]=" .. emit(value[key]) end
        return "{" .. table.concat(output, ",") .. "}"
    end
    return self.policy.luaPrefix .. emit(tree) .. self.policy.luaSuffix
end

function Model:snapshot()
    local current = Json.decode(self.process:run("settingsDescriptions"))
    local values = {}
    for _, item in ipairs(current) do values[item.name] = item.current end
    local options = Json.array({})
    for _, item in ipairs(self.policy.options) do
        assert(values[item.key] ~= nil, "missing_native_setting_" .. item.key)
        local option = {}; for key, value in pairs(item) do option[key] = value end
        option.value = values[item.key]
        options[#options + 1] = option
    end
    local labels = {}
    for key in pairs(self.catalog.messages) do if key:match("^settings%.") then labels[key:sub(10)] = self.catalog:text(key) end end
    local palette, colors = {}, {}
    local palettePath = self.paths:resolve("state", self.policy.palette.path)
    for line in File.read(palettePath):gmatch("[^\n]+") do
        local name, color = line:match('^([%w_]+)%s*=%s*"(#[%x]+)"%s*$')
        if name then colors[name] = color end
    end
    for role, name in pairs(self.policy.palette.roles) do
        local color = assert(colors[name], "missing_palette_color_" .. name)
        assert(color:match("^#%x%x%x%x%x%x$"), "invalid_palette_color")
        palette[role] = color
    end
    return {options=options, labels=labels, policy=self.policy, palette=palette, palettePath=palettePath}
end

function Model:write(key, value)
    self:validate(key, value)
    local state = self:state()
    state[key] = value
    local content = self:render(state)
    local stage = self.process:run("temporary", {"-d"}):gsub("\n$", "")
    local ok, failure = pcall(function()
        local config = self.paths:resolve("config", self.policy.configDirectory)
        self.process:run("copyTree", {config, stage .. "/hypr"})
        local staged = stage .. "/hypr/" .. assert(self.policy.generated:match("([^/]+)$"))
        self.publisher:publish(staged, content, self.policy.privateMode, function(path) self.process:run("validateLua", {path}) end)
        local output = self.process:run("settingsValidate", {"XDG_CONFIG_HOME=" .. stage, "OS_HYPR_CONFIG_ROOT=" .. stage .. "/hypr", "Hyprland", "--verify-config", "--config", stage .. "/" .. self.policy.main})
        assert(output:find(self.policy.validationSuccess, 1, true), "settings_validation_failed")
        local destination = self.paths:resolve("config", self.policy.generated)
        local previous = File.read(destination)
        local saved, save_error = pcall(function()
            self.publisher:publish(destination, content, self.policy.privateMode)
            self.process:run("settingsReload")
            assert(self.process:run("settingsErrors"):match("^%s*$"), "native_settings_errors")
            self.publisher:publish(self.paths:resolve("config", self.policy.state), Json.encode(state), self.policy.privateMode)
        end)
        if not saved then
            self.publisher:publish(destination, previous, self.policy.privateMode)
            self.process:run("settingsReload")
            error(save_error)
        end
    end)
    self.process:run("removeDirectory", {stage})
    assert(ok, failure)
    return self:snapshot()
end

return Model
