local Configuration = {}
Configuration.__index = Configuration

function Configuration.new(paths, process, policy)
    return setmetatable({paths=paths, process=process, policy=policy}, Configuration)
end

function Configuration:probe(command, path)
    local status = self.process:status(command, {path})
    assert(status == 0 or status == 1, "configuration_path_probe_failed")
    return status == 0
end

function Configuration:migrate()
    local policy, process = self.policy, self.process
    local old, target = self.paths:resolve("home", policy.legacy), self.paths:resolve("home", policy.directory)
    assert(old ~= target and old:match("^(.*)/[^/]+$") == target:match("^(.*)/[^/]+$") and target:match("([^/]+)$") == policy.link, "invalid_configuration_namespace_policy")
    assert(not self:probe("isLink", target), "redirected_configuration_namespace")
    assert(not self:probe("pathExists", target) or self:probe("isDirectory", target), "invalid_configuration_namespace")
    if self:probe("isLink", old) then
        assert(process:run("readLink", {old}):gsub("\n$", "") == policy.link and self:probe("isDirectory", target), "unexpected_configuration_link")
        return
    end
    assert(not self:probe("pathExists", old) or self:probe("isDirectory", old), "invalid_legacy_configuration")
    local entries = {}
    if self:probe("isDirectory", old) then
        for path in process:run("runtimeFiles", {old, "-mindepth", "1", "-maxdepth", "1", "-print0"}):gmatch("[^%z]+") do
            local destination = target .. "/" .. assert(path:match("([^/]+)$"))
            assert(not self:probe("pathExists", destination) and not self:probe("isLink", destination), "configuration_collision")
            entries[#entries + 1] = path
        end
    end
    process:run("directory", {target})
    for _, path in ipairs(entries) do
        process:run("moveNoClobber", {path, target .. "/"})
        assert(not self:probe("pathExists", path) and not self:probe("isLink", path), "configuration_move_failed")
    end
    if self:probe("isDirectory", old) then process:run("removeEmptyDirectory", {old}) end
    process:run("symbolicLink", {policy.link, old})
end

return Configuration
