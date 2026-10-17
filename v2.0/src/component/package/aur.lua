local File = require("core.file")
local Installer = {}
Installer.__index = Installer

function Installer.new(process, policy, user)
    return setmetatable({ process = process, policy = policy, user = user }, Installer)
end

function Installer.dependencies(source, architecture)
    local result = {}
    for line in source:gmatch("[^\r\n]+") do
        local field, value = line:match("^%s*(%S+)%s*=%s*(%S+)")
        if
            field
            and (
                field == "depends"
                or field == "makedepends"
                or field == "depends_" .. architecture
                or field == "makedepends_" .. architecture
            )
        then
            assert(value:match("^[A-Za-z0-9@._+-]+[<>=]*[A-Za-z0-9:._+~%-]*$"), "invalid_aur_dependency")
            result[#result + 1] = value
        end
    end
    return result
end

function Installer.integrity(source)
    if source:find("\nvalidpgpkeys=", 1, true) or source:match("^validpgpkeys=") then return true end
    local checksummed = source:match("\nsha256sums=")
        or source:match("^sha256sums=")
        or source:match("\nsha512sums=")
        or source:match("^sha512sums=")
        or source:match("\nb2sums=")
        or source:match("^b2sums=")
        or source:match("\nsha256sums_x86_64=")
        or source:match("^sha256sums_x86_64=")
    local maintainer
    for line in source:gmatch("[^\r\n]+") do
        local address = line:match("^#[ \t]*Maintainer[ \t]*:[ \t]*[^<]+<([^>]+)>")
        if address and (address:find("@", 1, true) or address:match("^contact: https://[^%s<>]+$")) then
            maintainer = true
            break
        end
    end
    return checksummed ~= nil and not source:find("SKIP", 1, true) and maintainer ~= nil
end

function Installer:artifact(directory, package)
    local process = self.process
    local output = process:run("aurArtifacts", {
        directory,
        "-maxdepth",
        "1",
        "-type",
        "f",
        "-name",
        package .. "-*.pkg.tar.*",
        "!",
        "-name",
        "*.sig",
        "-print0",
    })
    local selected
    for path in output:gmatch("[^%z]+") do
        local name = process:run("aurArtifactName", { path }):gsub("[\r\n]+$", "")
        if name == package then
            assert(not selected, "ambiguous_aur_artifact")
            selected = path
        end
    end
    assert(selected, "aur_artifact_missing")
    return selected
end

function Installer:install(package)
    assert(self.process:run("identity"):match("^0%s*$"), "root_required")
    assert(type(package) == "string" and package ~= "", "env.aur_empty")
    assert(package:match("^[A-Za-z0-9._-]+$"), "env.aur_invalid")
    assert(type(self.user) == "string" and self.user:match("^[A-Za-z0-9._-]+$"), "invalid_build_user")
    local process, policy = self.process, self.policy
    process:run("aurBuildDependencies", policy.buildDependencies)
    local temporary = process:run("temporary", { "-d" }):gsub("[\r\n]+$", "")
    assert(temporary:sub(1, 1) == "/", "invalid_aur_temporary_directory")
    local source = temporary .. "/src"
    local ok, result = pcall(function()
        process:run("permissions", { "700", temporary })
        process:run("aurOwnership", { self.user, self.user, temporary })
        process:run(
            "aurClone",
            { self.user, "/usr/bin/git", "clone", "--quiet", "--depth", "1", policy.repository:format(package), source }
        )
        assert(Installer.integrity(File.read(source .. "/PKGBUILD")), "env.aur_no_integrity")
        local metadata =
            process:run("aurPrintSourceInfo", { self.user, "/usr/bin/makepkg", "--printsrcinfo", "--dir", source })
        local architecture = process:run("aurArchitecture"):gsub("[\r\n]+$", "")
        assert(architecture:match("^[A-Za-z0-9_]+$"), "invalid_build_architecture")
        local dependencies = Installer.dependencies(metadata, architecture)
        if #dependencies > 0 then
            local missing, status = process:capture("aurMissingDependencies", dependencies)
            assert(status == 0 or status == policy.missingDependenciesStatus, "env.aur_verify_failed")
            local packages = {}
            for dependency in missing:gmatch("[^\r\n]+") do
                packages[#packages + 1] = dependency
            end
            if #packages > 0 then process:run("aurInstallDependencies", packages) end
        end
        process:run("aurBuild", { self.user, "/usr/bin/makepkg", "--noconfirm", "--dir", source })
        process:run("aurInstallArtifact", { self:artifact(source, package) })
        return package
    end)
    local cleanupOk, cleanupFailure = pcall(process.run, process, "removeDirectory", { temporary })
    assert(cleanupOk, cleanupFailure)
    assert(ok, result)
    return result
end

return Installer
