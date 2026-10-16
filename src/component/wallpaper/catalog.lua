local File = require("core.file")
local Process = require("core.process")
local Catalog = {}
Catalog.__index = Catalog

function Catalog.new(process, archive)
    return setmetatable({process=process, archive=archive}, Catalog)
end

function Catalog:entries(directory)
    local entries = self.process:run("wallpaperEntries", {directory, "-mindepth", "1", "-maxdepth", "1", "-print0"})
    local result = {}
    for path in entries:gmatch("([^%z]+)%z") do result[#result + 1] = path end
    return result
end

function Catalog:retire(path)
    self.process:run("directory", {self.archive})
    local directory = self.process:run("temporary", {"-d", self.archive .. "/retired.XXXXXXXX"}):gsub("\n$", "")
    self.process:run("move", {path, directory .. "/" .. assert(path:match("([^/]+)$"))})
end

function Catalog.run(root, output, chooser, archive, policy_path)
    local policy = File.json(policy_path)
    assert(#policy.variants == 1, "single_wallpaper_required")
    local identifier = assert(policy.variants[1].id)
    assert(identifier:match("^[a-z][a-z-]*$"), "invalid_wallpaper_identifier")
    local name = identifier .. ".png"
    local target = output .. "/" .. name
    assert(#File.read(target) > 0, "wallpaper_missing")
    local catalog = Catalog.new(Process.new(File.json(root .. "/data/core/commands.json")), archive)
    catalog.process:run("directory", {chooser})
    for _, path in ipairs(catalog:entries(output)) do
        if path ~= target and path:match("%.png$") then catalog:retire(path) end
    end
    for _, path in ipairs(catalog:entries(chooser)) do
        if path ~= chooser .. "/" .. name then catalog:retire(path) end
    end
    local destination = chooser .. "/" .. name
    local existing = io.open(destination, "rb")
    if existing then
        assert(existing:close())
        local resolved = catalog.process:run("realpath", {destination}):gsub("\n$", "")
        if resolved == target then return end
        catalog:retire(destination)
    end
    local staging = catalog.process:run("temporary", {"-d", chooser .. "/.publish.XXXXXXXX"}):gsub("\n$", "")
    local temporary = staging .. "/" .. name
    catalog.process:run("symbolicLink", {target, temporary})
    assert(os.rename(temporary, destination))
    assert(os.remove(staging))
end

return Catalog
