local Paths = {}
Paths.__index = Paths

function Paths.new(policy, environment)
    return setmetatable({ policy = assert(policy), getenv = environment or os.getenv }, Paths)
end

function Paths:resolve(name, relative)
    local definition = assert(self.policy.roots[name], "unknown_path_root")
    local home = assert(self.getenv(self.policy.homeVariable), "home_required")
    assert(home:sub(1, 1) == "/", "absolute_home_required")
    local directory = self.getenv(definition.variable)
    if not directory or directory == "" then directory = home .. "/" .. definition.relative end
    assert(directory:sub(1, 1) == "/" and relative:sub(1, 1) ~= "/", "invalid_path")
    for segment in relative:gmatch("[^/]+") do
        assert(segment ~= "..", "unsafe_path")
    end
    return directory:gsub("/+$", "") .. "/" .. relative
end

function Paths:protectHome(process, home)
    assert(type(home) == "string" and home:sub(1, 1) == "/", "invalid_home_path")
    local target = process:run("realpath", { home }):gsub("\n$", "")
    local metadata = assert(tonumber(process:run("fileMode", { target }), 16))
    assert(metadata & 0xF000 == 0x4000, "non_directory_home")
    local definition = assert(self.policy.homeMaximumMode, "home_mode_required")
    assert(definition:match("^7[0-7][0-7]$"), "invalid_home_mode")
    local maximum = assert(tonumber(definition, 8))
    local current = metadata & 0xFFF
    local secured = (current & 0xE00) | (current & maximum & 0x1FF)
    if secured ~= current then process:run("permissions", { ("%o"):format(secured), target }) end
end
function Paths:guardDirectory(process, base, relative)
    assert(relative:sub(1, 1) ~= "/", "invalid_managed_directory")
    local path = base
    for segment in relative:gmatch("[^/]+") do
        assert(segment ~= "..", "unsafe_managed_directory")
        path = path .. "/" .. segment
        assert(process:status("isLink", { path }) == 1, "redirected_managed_directory")
        local exists = process:status("pathExists", { path })
        assert(exists == 0 or exists == 1, "managed_directory_probe_failed")
        if exists == 0 then assert(process:status("isDirectory", { path }) == 0, "non_directory_managed_path") end
    end
end

return Paths
