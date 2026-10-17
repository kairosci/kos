local File = require("core.file")
local Kernel = require("component.security.kernel")

return function(suite, root)
    local policy = File.json(root .. "/data/component/security/kernel.json")

    local function fixture(values)
        local calls = {}
        local process = {
            run = function(_, name)
                calls[#calls + 1] = { "run", name }
                if name == "identity" then return "0\n" end
                error("unexpected_run_" .. name)
            end,
            status = function(_, name)
                calls[#calls + 1] = { "status", name }
                assert(name == "sysctlSystem")
                return 0
            end,
            capture = function(_, name, arguments)
                assert(name == "sysctlPrivileged")
                assert(arguments[1] == "-n")
                local value = values[arguments[2]]
                if value == nil then return "", 1 end
                return value .. "\n", 0
            end,
        }
        local published = {}
        local adapters = {
            publisher = {
                publish = function(_, path, content, mode)
                    published[#published + 1] = { path = path, content = content, mode = mode }
                end,
            },
            read_file = function(path)
                for _, file in ipairs(policy.files) do
                    if file.path == path then return file.content end
                end
                error("unexpected_read_" .. path)
            end,
        }
        return Kernel.new(process, policy, nil, adapters), calls, published, process
    end

    suite:test("kernel policy contains persistent controls and runtime assertions", function()
        assert(#policy.files == 4)
        assert(#policy.verification == 19)
        for _, file in ipairs(policy.files) do
            assert(file.path:sub(1, 1) == "/" and file.mode == "644")
            assert(file.content:sub(-1) == "\n")
        end
    end)

    suite:test("kernel apply publishes each canonical file before applying sysctl", function()
        local kernel, calls, published = fixture({})
        kernel:apply()
        assert(#published == #policy.files)
        for index, file in ipairs(policy.files) do
            assert(published[index].path == file.path)
            assert(published[index].content == file.content)
            assert(published[index].mode == file.mode)
        end
        assert(calls[#calls][1] == "status" and calls[#calls][2] == "sysctlSystem")
    end)

    suite:test("kernel apply refuses unprivileged identities", function()
        local kernel, _, _, process = fixture({})
        process.run = function(_, name)
            assert(name == "identity")
            return "1000\n"
        end
        suite:reject(function() kernel:apply() end)
    end)

    suite:test("kernel verification detects configuration and runtime drift", function()
        local values = {}
        for _, setting in ipairs(policy.verification) do values[setting[1]] = setting[2] end
        local kernel = fixture(values)
        assert(kernel:verify())
        values["kernel.randomize_va_space"] = "0"
        assert(not kernel:verify())
    end)
end
