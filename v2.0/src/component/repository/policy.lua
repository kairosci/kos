local File = require("core.file")
local Json = require("core.json")
local Policy = {}
Policy.__index = Policy

function Policy.new(root, process, catalog, policy, input, output)
    return setmetatable({
        root = root,
        process = process,
        catalog = catalog,
        policy = policy,
        input = input or io.stdin,
        output = output or io.stdout,
    }, Policy)
end

function Policy.matches(actual, expected)
    if expected == Json.null or actual == Json.null then return actual == expected end
    if Json.isArray(expected) then
        if not Json.isArray(actual) or #actual ~= #expected then return false end
        local used = {}
        for _, value in ipairs(expected) do
            local found
            for index, item in ipairs(actual) do
                if not used[index] and Policy.matches(item, value) then
                    found = index
                    break
                end
            end
            if not found then return false end
            used[found] = true
        end
        return true
    end
    if type(expected) ~= "table" or type(actual) ~= "table" or Json.isArray(actual) then return actual == expected end
    for key, value in pairs(expected) do
        if not Policy.matches(actual[key], value) then return false end
    end
    return true
end

function Policy:pre_push()
    for line in self.input:lines() do
        local _, _, remote = line:match("^(%S+)%s+(%x+)%s+(%S+)%s+%x+%s*$")
        assert(remote, "invalid_git_push_record")
        for _, protected in ipairs(self.policy.protectedRefs) do
            if remote == protected then error(self.catalog:text("git.main_push_forbidden"), 0) end
        end
    end
    return 0
end

function Policy:repository(value)
    if not value then value = self.process:run(self.policy.repositoryCommand):gsub("\n$", "") end
    local owner, name = value:match("^([%w_.-]+)/([%w_.-]+)$")
    assert(
        owner and name and owner ~= "." and owner ~= ".." and name ~= "." and name ~= "..",
        "invalid_repository_name"
    )
    return owner .. "/" .. name
end

function Policy:rulesets(collection)
    local arguments = { collection .. self.policy.query }
    for _, value in ipairs(self.policy.pagination) do
        arguments[#arguments + 1] = value
    end
    local pages = Json.decode(self.process:run(self.policy.apiCommand, arguments))
    assert(Json.isArray(pages), "invalid_repository_rulesets")
    local rulesets = Json.array({})
    for _, page in ipairs(pages) do
        assert(Json.isArray(page), "invalid_repository_rulesets")
        for _, ruleset in ipairs(page) do
            assert(
                type(ruleset) == "table" and not Json.isArray(ruleset) and type(ruleset.name) == "string",
                "invalid_repository_rulesets"
            )
            rulesets[#rulesets + 1] = ruleset
        end
    end
    return rulesets
end

function Policy:reconcile(repository, apply)
    repository = self:repository(repository)
    local expected = File.json(self.root .. "/" .. self.policy.ruleset)
    local collection = self.policy.rulesetsEndpoint:format(repository)
    local id
    for _, ruleset in ipairs(self:rulesets(collection)) do
        if ruleset.name == expected.name then
            assert(
                not id and type(ruleset.id) == "number" and ruleset.id % 1 == 0 and ruleset.id > 0,
                "ambiguous_repository_ruleset"
            )
            id = ruleset.id
        end
    end
    if apply then
        local source = self.root .. "/" .. self.policy.ruleset
        local arguments = { collection, "--method", "POST", "--input", source }
        if id then arguments = { collection .. "/" .. id, "--method", "PUT", "--input", source } end
        local result = Json.decode(self.process:run(self.policy.apiCommand, arguments))
        assert(
            type(result) == "table"
                and not Json.isArray(result)
                and type(result.id) == "number"
                and result.id > 0
                and result.id % 1 == 0,
            "invalid_published_ruleset"
        )
        id = result.id
    end
    assert(id, "repository_ruleset_missing")
    local active = Json.decode(self.process:run(self.policy.apiCommand, { collection .. "/" .. id }))
    assert(Policy.matches(active, expected), "repository_ruleset_drift")
    self.output:write(self.catalog:text("git.ruleset_verified", repository), "\n")
    return 0
end

return Policy
