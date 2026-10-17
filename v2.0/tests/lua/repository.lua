local File = require("core.file")
local Json = require("core.json")
local Policy = require("component.repository.policy")

return function(suite, root, process)
    local policy = File.json(root .. "/data/repository/policy.json")
    local expected = File.json(root .. "/" .. policy.ruleset)
    local function output()
        return {text="", write=function(self, ...) for _, value in ipairs({...}) do self.text = self.text .. value end end}
    end
    local function catalog()
        return {text=function(_, key, value) return key .. ":" .. tostring(value) end}
    end
    local function reader(text)
        local lines = {}
        for line in (text:gsub("\n$", "") .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
        return {lines=function() local index = 0; return function() index = index + 1; return lines[index] end end}
    end

    suite:test("pre-push guard allows topic branches and repeated records", function()
        local guard = Policy.new(root, process, catalog(), policy, reader(
            "refs/heads/topic " .. ("a"):rep(40) .. " refs/heads/topic " .. ("b"):rep(40) .. "\n" ..
            "refs/heads/other " .. ("c"):rep(40) .. " refs/heads/other " .. ("d"):rep(40) .. "\n"))
        assert(guard:pre_push() == 0)
    end)
    suite:test("pre-push guard blocks direct and deleted main refs", function()
        for _, record in ipairs({
            "refs/heads/main " .. ("a"):rep(40) .. " refs/heads/main " .. ("b"):rep(40),
            "refs/heads/topic " .. ("a"):rep(40) .. " refs/heads/topic " .. ("b"):rep(40) .. "\n" ..
            "refs/heads/main " .. ("c"):rep(40) .. " refs/heads/main " .. ("d"):rep(40),
            "(delete) " .. ("0"):rep(40) .. " refs/heads/main " .. ("b"):rep(40)}) do
            suite:reject(function() Policy.new(root, process, catalog(), policy, reader(record)):pre_push() end)
        end
    end)
    suite:test("pre-push guard rejects malformed records", function()
        suite:reject(function() Policy.new(root, process, catalog(), policy, reader("refs/heads/topic nonsense")):pre_push() end)
        suite:reject(function() Policy.new(root, process, catalog(), policy, reader("refs/heads/topic " .. ("z"):rep(40) .. " refs/heads/main " .. ("b"):rep(40))):pre_push() end)
    end)

    suite:test("structural comparison keeps arrays ordered by cardinality and duplicates", function()
        local Case = function(actual, reference) return Policy.matches(Json.decode(actual), Json.decode(reference)) end
        assert(Case('{"rules":[1,2]}', '{"rules":[2,1]}'))
        assert(Case('{"rules":[1,1]}', '{"rules":[1,1]}'))
        assert(not Case('{"rules":[1,2,3]}', '{"rules":[1,2]}'))
        assert(not Case('{"rules":[1,1]}', '{"rules":[1,2]}'))
        assert(not Case('{"rules":[1,1]}', '{"rules":[1]}'))
    end)
    suite:test("structural comparison separates empty arrays objects and null", function()
        assert(Policy.matches(Json.decode("[]"), Json.decode("[]")))
        assert(Policy.matches(Json.decode("{}"), Json.decode("{}")))
        assert(not Policy.matches(Json.decode("[]"), Json.decode("{}")))
        assert(not Policy.matches(Json.decode("{}"), Json.decode("[]")))
        assert(not Policy.matches(Json.decode('{"conditions":{}}'), Json.decode('{"conditions":[]}')))
        assert(Policy.matches(Json.decode('{"a":null}'), Json.decode('{"a":null}')))
        assert(not Policy.matches(Json.decode('{"a":1}'), Json.decode('{"a":null}')))
        assert(not Policy.matches(Json.decode("{}"), Json.decode('{"a":null}')))
    end)
    suite:test("structural comparison permits metadata but rejects deviations", function()
        assert(Policy.matches(Json.decode('{"a":1,"extra":true,"nested":{"x":[1]}}'), Json.decode('{"a":1}')))
        assert(not Policy.matches(Json.decode('{"b":1}'), Json.decode('{"a":1}')))
        assert(not Policy.matches(Json.decode('{"a":"1"}'), Json.decode('{"a":1}')))
        assert(not Policy.matches(Json.decode('{"rules":[{"type":"creation"},{"type":"update"}]}'), Json.decode('{"rules":[{"type":"creation"}]}')))
        assert(not Policy.matches(Json.decode('{"bypass_actors":[{"actor_id":1}]}'), Json.decode('{"bypass_actors":[]}')))
    end)

    local function candidate()
        local value = Json.decode(Json.encode(expected))
        value.id = 24468699
        value.source_type = "Repository"
        value.source = "kairosci/os"
        value.node_id = "RRS_fixture"
        value.created_at = "2026-10-04T22:48:47.949+02:00"
        value.updated_at = "2026-10-13T18:07:22.463+02:00"
        value.current_user_can_bypass = "never"
        value._links = Json.decode('{"self":{"href":"https://api.github.com/repos/kairosci/os/rulesets/24468699"}}')
        return value
    end
    local function backend(listing, reference)
        local calls = {}
        return {calls=calls, run=function(_, command, arguments)
            calls[#calls + 1] = {command=command, arguments=arguments}
            if command == "repositoryName" then return "kairosci/os\n" end
            assert(command == "repositoryApi", command)
            if arguments[1]:find("?", 1, true) then
                assert(arguments[2] == "--paginate" and arguments[3] == "--slurp", "missing_pagination")
                return type(listing) == "string" and listing or Json.encode(listing)
            end
            if arguments[2] == "--method" then return Json.encode(reference.published) end
            return type(reference.active) == "string" and reference.active or Json.encode(reference.active)
        end}
    end
    local function pages(first, second)
        return Json.array({Json.array(first), Json.array(second)})
    end

    suite:test("reconcile discovers a ruleset across pages and confirms the active policy", function()
        local calls = backend(pages({{name="obsolete", id=1}}, {{name=expected.name, id=24468699}}), {active=candidate()})
        local target = output()
        assert(Policy.new(root, calls, catalog(), policy, reader(""), target):reconcile("kairosci/os", false) == 0)
        assert(target.text == "git.ruleset_verified:kairosci/os\n")
        assert(calls.calls[1].command == "repositoryApi" and calls.calls[1].arguments[1]:find("rulesets?", 1, true))
    end)
    suite:test("reconcile rejects an ambiguous duplicate name across pages", function()
        local duplicate = pages({{name=expected.name, id=1}}, {{name=expected.name, id=2}})
        suite:reject(function() Policy.new(root, backend(duplicate, {active=candidate()}), catalog(), policy, reader(""), output()):reconcile("kairosci/os", false) end)
    end)
    suite:test("reconcile rejects policy drift from extra rules bypass actors or changes", function()
        local drifted = candidate()
        drifted.bypass_actors = Json.decode('[{"actor_id":1,"actor_type":"Team","bypass_mode":"always"}]')
        suite:reject(function() Policy.new(root, backend(pages({}, {{name=expected.name, id=24468699}}), {active=drifted}), catalog(), policy, reader(""), output()):reconcile("kairosci/os", false) end)
        local updated = candidate()
        updated.rules[#updated.rules + 1] = Json.decode('{"type":"update"}')
        suite:reject(function() Policy.new(root, backend(pages({}, {{name=expected.name, id=24468699}}), {active=updated}), catalog(), policy, reader(""), output()):reconcile("kairosci/os", false) end)
    end)
    suite:test("reconcile creates a missing ruleset with POST and verifies it", function()
        local calls = backend(pages({}, {}), {published={id=77}, active=candidate()})
        assert(Policy.new(root, calls, catalog(), policy, reader(""), output()):reconcile("kairosci/os", true) == 0)
        local publish = calls.calls[#calls.calls - 1]
        assert(publish.arguments[1] == "repos/kairosci/os/rulesets" and publish.arguments[2] == "--method" and publish.arguments[3] == "POST")
        assert(publish.arguments[5] == root .. "/" .. policy.ruleset)
    end)
    suite:test("reconcile updates an existing ruleset with PUT and verifies it", function()
        local calls = backend(pages({}, {{name=expected.name, id=24468699}}), {published={id=24468699}, active=candidate()})
        assert(Policy.new(root, calls, catalog(), policy, reader(""), output()):reconcile("kairosci/os", true) == 0)
        local publish = calls.calls[#calls.calls - 1]
        assert(publish.arguments[1] == "repos/kairosci/os/rulesets/24468699" and publish.arguments[3] == "PUT")
    end)
    suite:test("reconcile rejects malformed pages and missing canonical rulesets", function()
        suite:reject(function() Policy.new(root, backend('{"name":"not-a-list"}', {active=candidate()}), catalog(), policy, reader(""), output()):reconcile("kairosci/os", false) end)
        suite:reject(function() Policy.new(root, backend(pages({{name="obsolete", id=1}}, {{name="other", id=2}}), {active=candidate()}), catalog(), policy, reader(""), output()):reconcile("kairosci/os", false) end)
    end)
    suite:test("reconcile rejects an invalid repository name before any API call", function()
        local calls = backend(pages({}, {}), {active=candidate()})
        suite:reject(function() Policy.new(root, calls, catalog(), policy, reader(""), output()):reconcile("../etc", false) end)
        assert(#calls.calls == 0)
    end)
end
