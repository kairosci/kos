local File = require("core.file")
local Assessment = require("component.platform.assessment")
return function(suite, root)
    local policy = File.json(root .. "/data/component/platform/parity.json")
    local responses = {
        platformPackages = "linux\nquickshell\nomarchy\ncustom-app\nshared\n",
        platformRepositories = "core\nextra\nmultilib\nomarchy\n",
        platformOfficialPackages = "linux\nquickshell\nshared\n",
        platformRepositoryCatalog = "omarchy omarchy 1\nomarchy custom-app 1\nomarchy shared 1\ncore shared 1\n",
        platformRuntimeFiles = "/usr/share/omarchy/\n/usr/share/omarchy/shell/shell.qml\n",
        platformKernel = "fixture-kernel\n",
    }
    local packageStatus, scanStatus, inventoryFailure = 0, 0, false
    local backend = {
        run = function(_, name, arguments)
            assert(not (inventoryFailure and name == "platformPackages"), "inventory_failed")
            if name == "platformOfficialPackages" then assert(arguments == policy.officialRepositories) end
            return assert(responses[name], name)
        end,
        status = function(_, name)
            assert(name == "platformRuntimeInstalled")
            return packageStatus
        end,
        capture = function(_, name)
            if name == "platformRuntimeInstalled" then return "runtime package output", packageStatus end
            assert(name == "platformReferences")
            return scanStatus == 0 and "fixture/source.lua\n" or "", scanStatus
        end,
    }
    local assessment = Assessment.new(root, backend, policy)
    suite:test("Arch inventory separates official packages and runtime ownership", function()
        local report = assessment:report()
        assert(
            report.packagesWithoutOfficialSource[1] == "omarchy"
                and report.packagesWithoutOfficialSource[2] == "custom-app"
        )
        assert(
            report.runtimeRepositoryConfigured
                and report.packagesFromRuntimeRepository[1] == "omarchy"
                and report.packagesFromRuntimeRepository[2] == "custom-app"
        )
        assert(report.packagesFromRuntimeRepository[3] == "shared")
        assert(
            #report.packagesFromRuntimeRepositoryWithoutOfficialSource == 2
                and report.packagesFromRuntimeRepositoryWithoutOfficialSource[1] == "omarchy"
                and report.packagesFromRuntimeRepositoryWithoutOfficialSource[2] == "custom-app"
        )
        assert(#report.externalPackages == 1 and report.runtimeFileCount == 1 and #report.dependentSources == 1)
        assert(report.runningKernel == "fixture-kernel" and #report.capabilities == 16)
        for _, capability in ipairs(report.capabilities) do
            assert(capability.parity == "unverified")
        end
        assert(not report.readyToRemoveRuntime and not report.readyToRemoveRepository and report.requiresTrialBoot)
    end)
    suite:test("repository removal is ready after every installed repository only package is replaced", function()
        responses.platformPackages = "linux\nquickshell\nshared\n"
        local report = assessment:report()
        assert(
            report.readyToRemoveRepository
                and #report.packagesFromRuntimeRepositoryWithoutOfficialSource == 0
                and report.runtimeRepositoryConfigured
        )
        responses.platformPackages = "linux\nquickshell\nomarchy\ncustom-app\nshared\n"
    end)
    suite:test("absence of runtime packages and references cannot establish Arch parity", function()
        packageStatus, scanStatus = 1, 1
        local report = assessment:report()
        assert(report.runtimeFileCount == 0 and #report.dependentSources == 0 and not report.readyToRemoveRuntime)
    end)
    suite:test("inventory and reference scanning errors prevent a parity verdict", function()
        inventoryFailure = true
        suite:reject(function()
            assessment:report()
        end)
        inventoryFailure, scanStatus = false, 2
        suite:reject(function()
            assessment:report()
        end)
        scanStatus, packageStatus = 0, 44
        suite:reject(function()
            assessment:report()
        end)
    end)
    suite:test("malformed repository catalog cannot authorize repository removal", function()
        packageStatus = 0
        responses.platformRepositoryCatalog = "omarchy malformed\n"
        suite:reject(function()
            assessment:report()
        end)
        responses.platformRepositoryCatalog =
            "omarchy omarchy 1\nomarchy custom-app 1\nomarchy shared 1\ncore shared 1\n"
    end)
end
