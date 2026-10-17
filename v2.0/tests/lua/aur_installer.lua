local File = require("core.file")
local Installer = require("component.package.aur")

return function(suite, root, process)
    local policy = File.json(root .. "/data/component/package/aur.json")
    suite:test("AUR source dependencies follow architecture and ignore optional entries", function()
        local values = Installer.dependencies(
            "depends = gtk3\nmakedepends = patch\ndepends_x86_64 = libx11\ndepends_aarch64 = wrong\noptdepends = fonts: optional\n",
            "x86_64"
        )
        assert(#values == 3 and values[1] == "gtk3" and values[2] == "patch" and values[3] == "libx11")
    end)
    suite:test("AUR source dependencies reject malformed package metadata", function()
        suite:reject(function()
            Installer.dependencies("depends = bad/name\n", "x86_64")
        end)
    end)
    suite:test("AUR integrity accepts signed keys or checksums with a named maintainer", function()
        assert(Installer.integrity("validpgpkeys=('ABC')\n"))
        assert(Installer.integrity("# Maintainer: Example <maintainer@example.org>\nsha256sums=('abc')\n"))
        assert(Installer.integrity("# Maintainer: Example <contact: https://example.org>\nsha256sums=('abc')\n"))
        assert(not Installer.integrity("# Maintainer: Example <maintainer@example.org>\nsha256sums=('SKIP')\n"))
        assert(not Installer.integrity("# Maintainer: Example <website>\nsha256sums=('abc')\n"))
        assert(not Installer.integrity("sha256sums=('abc')\n"))
    end)
    suite:test("AUR installation builds as user and installs only the matching package artifact", function()
        local buildRoot, artifact
        local events = {}
        local function write(path, content)
            local file = assert(io.open(path, "wb"))
            assert(file:write(content))
            assert(file:close())
        end
        local backend = {
            run = function(_, name, arguments)
                events[#events + 1] = name
                if name == "identity" then
                    return "0\n"
                elseif name == "temporary" then
                    buildRoot = process:run("temporary", { "-d" }):gsub("[\r\n]+$", "")
                    return buildRoot .. "\n"
                elseif name == "permissions" then
                    return process:run("permissions", arguments)
                elseif name == "aurBuildDependencies" then
                    assert(arguments[1] == "base-devel" and arguments[3] == "wget")
                    return ""
                elseif name == "aurOwnership" then
                    assert(arguments[1] == "builder" and arguments[2] == "builder")
                    return ""
                elseif name == "aurClone" then
                    assert(arguments[1] == "builder" and arguments[2] == "/usr/bin/git" and arguments[3] == "clone")
                    local directory = arguments[#arguments]
                    process:run("directory", { directory })
                    write(
                        directory .. "/PKGBUILD",
                        "# Maintainer: Example <maintainer@example.org>\npkgname=fixture\nsha256sums=('abc')\n"
                    )
                    return ""
                elseif name == "aurPrintSourceInfo" then
                    assert(arguments[1] == "builder" and arguments[#arguments] == buildRoot .. "/src")
                    return "depends = gtk3\nmakedepends = make\n"
                elseif name == "aurArchitecture" then
                    return "x86_64\n"
                elseif name == "aurInstallDependencies" then
                    assert(#arguments == 1 and arguments[1] == "gtk3")
                    return ""
                elseif name == "aurBuild" then
                    assert(arguments[1] == "builder" and arguments[#arguments] == buildRoot .. "/src")
                    artifact = buildRoot .. "/src/fixture-1-1-any.pkg.tar.zst"
                    write(artifact, "fixture")
                    return ""
                elseif name == "aurArtifacts" then
                    return artifact .. "\0"
                elseif name == "aurArtifactName" then
                    return "fixture\n"
                elseif name == "aurInstallArtifact" then
                    assert(arguments[1] == artifact)
                    return ""
                elseif name == "removeDirectory" then
                    return process:run("removeDirectory", arguments)
                end
                error("unexpected_command_" .. name)
            end,
            capture = function(_, name, arguments)
                assert(name == "aurMissingDependencies" and #arguments == 2)
                return "gtk3\n", 127
            end,
        }
        assert(Installer.new(backend, policy, "builder"):install("fixture") == "fixture")
        assert(events[#events - 1] == "aurInstallArtifact" and events[#events] == "removeDirectory")
        assert(process:status("pathExists", { buildRoot }) == 1)
    end)
    suite:test("AUR integrity failure cleans its temporary build tree", function()
        local buildRoot
        local backend = {
            run = function(_, name, arguments)
                if name == "identity" then
                    return "0\n"
                elseif name == "temporary" then
                    buildRoot = process:run("temporary", { "-d" }):gsub("[\r\n]+$", "")
                    return buildRoot .. "\n"
                elseif name == "aurBuildDependencies" then
                    return ""
                elseif name == "permissions" then
                    return process:run("permissions", arguments)
                elseif name == "aurOwnership" then
                    return ""
                elseif name == "aurClone" then
                    local directory = arguments[#arguments]
                    process:run("directory", { directory })
                    local file = assert(io.open(directory .. "/PKGBUILD", "wb"))
                    assert(file:write("# Maintainer: Example <maintainer@example.org>\nsha256sums=('SKIP')\n"))
                    assert(file:close())
                    return ""
                elseif name == "removeDirectory" then
                    return process:run("removeDirectory", arguments)
                end
                error("unexpected_command_" .. name)
            end,
        }
        suite:reject(function()
            Installer.new(backend, policy, "builder"):install("fixture")
        end)
        local cleanupStatus = process:status("pathExists", { buildRoot })
        assert(
            cleanupStatus == 1,
            "aur_temporary_cleanup_failed_" .. tostring(cleanupStatus) .. "_" .. tostring(buildRoot)
        )
    end)
    suite:test("AUR installation validates package and build user", function()
        local installer = Installer.new({}, policy, "builder")
        suite:reject(function()
            installer:install("bad/name")
        end)
        suite:reject(function()
            Installer.new({}, policy, ""):install("fixture")
        end)
    end)
end
