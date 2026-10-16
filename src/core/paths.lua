local Paths = {}
Paths.__index = Paths

function Paths.new(policy, environment)
    return setmetatable({policy=assert(policy), getenv=environment or os.getenv}, Paths)
end

function Paths:resolve(name, relative)
    local definition = assert(self.policy.roots[name], "unknown_path_root")
    local home = assert(self.getenv(self.policy.homeVariable), "home_required")
    assert(home:sub(1, 1) == "/", "absolute_home_required")
    local directory = self.getenv(definition.variable)
    if not directory or directory == "" then directory = home .. "/" .. definition.relative end
    assert(directory:sub(1, 1) == "/" and relative:sub(1, 1) ~= "/", "invalid_path")
    for segment in relative:gmatch("[^/]+") do assert(segment ~= "..", "unsafe_path") end
    return directory:gsub("/+$", "") .. "/" .. relative
end

return Paths
