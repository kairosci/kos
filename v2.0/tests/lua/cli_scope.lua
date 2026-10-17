local File = require("core.file")
return function(suite, root, process)
    local directory = process:run("temporary", { "-d" }):gsub("\n$", "")
    local project, trace = directory .. "/project", directory .. "/trace"
    local function write(relative, content)
        local destination = project .. "/" .. relative
        process:run("directory", { assert(destination:match("^(.*)/[^/]+$")) })
        local handle = assert(io.open(destination, "wb"))
        assert(handle:write(content))
        assert(handle:close())
    end
    write("scripts/setup.sh", (File.read(root .. "/scripts/setup.sh"):gsub("%$EUID", "0")))
    write("scripts/lib/i18n.sh", File.read(root .. "/scripts/lib/i18n.sh"))
    write("scripts/lib/target-user.sh", File.read(root .. "/scripts/lib/target-user.sh"))
    process:run("copyTree", { root .. "/data/catalog", project .. "/scripts/lib/messages" })
    write("scripts/lib/root-recovery.sh", "root_setup_persistent() { return 0; }\n")
    write(
        "scripts/lib/modules/00-env.sh",
        '[[ "${1:-}" == --functions-only ]] || exit 81\nprintf "helpers\\n" >> "$CLI_TEST_TRACE"\n'
    )
    write("scripts/lib/modules/36-os-cli.sh", 'printf "cli\\n" >> "$CLI_TEST_TRACE"\n')
    local function execute(extra)
        local arguments = {
            "OS_LOG_STDOUT=1",
            "CLI_TEST_TRACE=" .. trace,
            "/usr/bin/bash",
            project .. "/scripts/setup.sh",
            "--scope",
            "cli",
        }
        if extra then arguments[#arguments + 1] = extra end
        return process:capture("environment", arguments, true)
    end
    suite:test("CLI setup reaches only its session helpers and installer", function()
        local output, status = execute()
        assert(status == 0, output)
        assert(File.read(trace) == "helpers\ncli\n")
    end)
    suite:test("CLI setup refuses unrelated snapshot reset options", function()
        local _, status = execute("--reset-snapshots")
        assert(status ~= 0 and File.read(trace) == "helpers\ncli\n")
    end)
    process:run("removeDirectory", { directory })
end
