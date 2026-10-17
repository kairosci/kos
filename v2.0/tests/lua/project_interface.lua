local File = require("core.file")
local Catalog = require("core.catalog")
local Interface = require("component.project.interface")

return function(suite, root, process)
    local policy = File.json(root .. "/data/component/project/policy.json")
    local locale = File.json(root .. "/data/core/locale.json")
    local output = {text="", write=function(self, ...) for _, value in ipairs({...}) do self.text = self.text .. value end end}
    local status, uid, calls, entered = 0, "0", {}, true
    local backend = {
        commands=File.json(root .. "/data/core/commands.json"),
        run=function(_, name) assert(name == "identity"); return uid .. "\n" end,
        status=function(_, name, arguments) calls[#calls + 1] = {name=name, arguments=arguments}; return status end
    }
    local input = {read=function() if entered then return "" end end}
    local function localized(language)
        local catalog = Catalog.new(locale, root .. "/data/catalog", function(name) if name == "OS_LANG" then return language end end)
        return Interface.new(root, backend, catalog, policy, locale, output, input), catalog
    end
    suite:test("project help and language discovery render every supported catalog", function()
        for _, language in ipairs(locale.languages) do
            local interface, catalog = localized(language)
            output.text = ""; assert(interface:help() == 0)
            assert(output.text:find(catalog:text("make.setup"), 1, true))
            for _, row in ipairs(policy.help) do assert(output.text:find(row.target, 1, true)) end
            output.text = ""; interface:languages()
            assert(output.text:find(catalog:text("i18n.current"), 1, true) and output.text:find(language, 1, true))
            output.text = ""; interface:locale_status()
            assert(output.text:find("language=" .. language, 1, true) and output.text:find(root .. "/data/catalog", 1, true))
        end
        assert(#calls == 0)
    end)
    local interface = localized("en")
    suite:test("interactive launch invokes only the existing privileged setup pipeline", function()
        assert(interface:launch("project-launch", {}) == 0)
        local call = calls[#calls]
        assert(call.name == policy.privilegedCommand and #call.arguments == 1 and call.arguments[1] == root .. "/scripts/setup.sh")
    end)
    suite:test("failed setup preserves its exit status without prompting", function()
        status = 37; output.text = ""
        assert(interface:launch("project-launch", {}) == 37)
        assert(output.text == ""); status = 0
        entered = false; assert(interface:launch("project-launch", {}) == 1); entered = true
    end)
    suite:test("keyring selection rejects unsupported backends before escalation", function()
        local before = #calls
        suite:reject(function() interface:launch("project-keyring", {"other"}) end)
        suite:reject(function() interface:launch("project-keyring", {"gnome-keyring", "extra"}) end)
        assert(#calls == before)
        assert(interface:launch("project-keyring", {}) == 0)
        local call = calls[#calls]
        assert(call.name == policy.keyringCommand and call.arguments[1] == policy.keyringVariable .. "=" .. policy.defaultKeyring)
        assert(call.arguments[#call.arguments] == root .. "/scripts/setup.sh")
    end)
    suite:test("direct setup refuses an unprivileged identity", function()
        uid = "1000"; local before = #calls
        suite:reject(function() interface:launch("project-entry", {}) end)
        assert(#calls == before); uid = "0"
        assert(interface:launch("project-entry", {}) == 0 and calls[#calls].name == policy.directCommand)
    end)
    suite:test("logged setup reports the canonical log location", function()
        output.text = ""; interface:launch("project-run-setup", {})
        assert(output.text:find(root .. "/" .. policy.log, 1, true))
    end)
    suite:test("invalid launch arguments and absent pipelines cannot execute commands", function()
        local before = #calls
        suite:reject(function() interface:launch("project-launch", {"unexpected"}) end)
        suite:reject(function() interface:launch("unknown", {}) end)
        local missing = Interface.new(root .. "/missing", backend, select(2, localized("en")), policy, locale, output, input)
        suite:reject(function() missing:launch("project-launch", {}) end)
        assert(#calls == before)
    end)
end
