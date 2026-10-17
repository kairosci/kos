local File = require("core.file")
local Helper = {}
Helper.__index = Helper

function Helper.new(root, catalog, policy, output, errors)
    return setmetatable(
        { root = root, catalog = catalog, policy = policy, output = output or io.stdout, errors = errors or io.stderr },
        Helper
    )
end

function Helper:run(arguments)
    local topic = arguments[1] or self.policy.defaultTopic
    topic = self.policy.aliases[topic] or topic
    local messages = File.json(self.root .. "/" .. self.policy.help:format(self.catalog.language))
    local text = messages[topic]
    if not text then
        self.errors:write(self.catalog:text("terminal.helper_unknown", topic), "\n")
        return 1
    end
    self.output:write(text)
    if text:sub(-1) ~= "\n" then self.output:write("\n") end
    return 0
end

return Helper
