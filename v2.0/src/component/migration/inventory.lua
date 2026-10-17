local Json = require("core.json")
local File = require("core.file")
local Inventory = {}
Inventory.__index = Inventory

function Inventory.new(root, process, policy)
    local candidate = root
    if root:match("([^/]+)$") == policy.versionDirectory then candidate = assert(root:match("^(.*)/[^/]+$")) end
    local repository = process
        :run(
            "repositoryFiles",
            { "-c", "safe.directory=" .. candidate, "-C", candidate, "rev-parse", "--show-toplevel" }
        )
        :gsub("\n$", "")
    assert(repository:sub(1, 1) == "/", "repository_root_required")
    return setmetatable({ root = repository, process = process, policy = policy }, Inventory)
end

function Inventory:classify(path, content)
    if self.policy.starters[path] then
        assert(content == File.read(self.root .. "/" .. path), "starter_content_mismatch")
        local digest = self.process:run("digest", { self.root .. "/" .. path }):match("^(%x+)")
        assert(digest == self.policy.starters[path], "starter_changed_" .. path)
        return "starter"
    end
    if path:match("%.sh$") or content:match("^#![^\n]*[/ ]bash[ \n]") or content:match("^#![^\n]*[/ ]sh[ \n]") then
        return "shell"
    end
    if path:match("%.rb$") then return "ruby" end
    return nil
end

function Inventory:report()
    local arguments = {
        "-c",
        "safe.directory=" .. self.root,
        "-C",
        self.root,
        "ls-files",
        "-z",
        "--cached",
        "--others",
        "--exclude-standard",
        "--",
    }
    for _, directory in ipairs(self.policy.roots) do
        arguments[#arguments + 1] = directory
    end
    local files = self.process:run("repositoryFiles", arguments)
    local result =
        { complete = true, remaining = Json.array({}), starters = Json.array({}), legacyLayout = Json.array({}) }
    local seen = {}
    for path in files:gmatch("([^%z]+)%z") do
        if not seen[path] then
            seen[path] = true
            local handle, failure, code = io.open(self.root .. "/" .. path, "rb")
            if handle then
                local content, read_failure, read_code = handle:read("a")
                assert(handle:close())
                if not content then
                    local mode = tonumber(self.process:run("fileMode", { self.root .. "/" .. path }), 16)
                    assert(read_code == 21 and mode and mode & 0xF000 == 0xA000, read_failure)
                end
                local kind = content and self:classify(path, content)
                if content and kind ~= "starter" then
                    for _, prefix in ipairs(self.policy.legacyRoots) do
                        if path:sub(1, #prefix) == prefix then
                            result.legacyLayout[#result.legacyLayout + 1] = path
                            result.complete = false
                            break
                        end
                    end
                end
                if kind == "starter" then
                    result.starters[#result.starters + 1] = path
                elseif kind then
                    result.complete = false
                    result.remaining[#result.remaining + 1] = { path = path, language = kind }
                end
            else
                assert(code == 2, failure)
            end
        end
    end
    table.sort(result.remaining, function(left, right)
        return left.path < right.path
    end)
    table.sort(result.legacyLayout)
    table.sort(result.starters)
    return result
end

return Inventory
