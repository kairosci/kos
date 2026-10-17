local Json = require("core.json")
local Assessment = {}
Assessment.__index = Assessment

function Assessment.new(root, process, policy)
    return setmetatable({root=root, process=process, policy=policy}, Assessment)
end

function Assessment.lines(text)
    local result = Json.array({})
    for line in text:gmatch("[^\r\n]+") do result[#result + 1] = line end
    return result
end

function Assessment:report()
    local policy, process = self.policy, self.process
    local packages = Assessment.lines(process:run("platformPackages"))
    local installed, official = {}, {}
    for _, package in ipairs(packages) do installed[package] = true end
    local repositories = Assessment.lines(process:run("platformRepositories"))
    for _, package in ipairs(Assessment.lines(process:run("platformOfficialPackages", policy.officialRepositories))) do official[package] = true end
    local arguments = {"-l", "-e", policy.runtimeReferencePattern}
    for _, relative in ipairs(policy.sourceDirectories) do arguments[#arguments + 1] = self.root .. "/" .. relative end
    local references, status = process:capture("platformReferences", arguments)
    assert(status == 0 or status == 1, "runtime_reference_scan_failed")
    local _, exists = process:capture("platformRuntimeInstalled", {policy.runtimePackage})
    assert(exists == 0 or exists == 1, "runtime_package_probe_failed")
    local count = 0
    if exists == 0 then
        for _, path in ipairs(Assessment.lines(process:run("platformRuntimeFiles", {policy.runtimePackage}))) do
            if path:sub(-1) ~= "/" then count = count + 1 end
        end
    end
    local report = {schemaVersion=policy.schemaVersion, target=policy.target,
        runningKernel=process:run("platformKernel"):gsub("\n$", ""),
        externalPackages=Json.array({}), repositories=repositories, packagesWithoutOfficialSource=Json.array({}),
        dependentSources=Assessment.lines(references), runtimeFileCount=count, capabilities=Json.array({}),
        readyToRemoveRuntime=false, readyToRemoveRepository=false, requiresTrialBoot=true}
    for _, package in ipairs(policy.externalPackages) do if installed[package] then report.externalPackages[#report.externalPackages + 1] = package end end
    for _, package in ipairs(packages) do if not official[package] then report.packagesWithoutOfficialSource[#report.packagesWithoutOfficialSource + 1] = package end end
    for _, capability in ipairs(policy.requiredCapabilities) do
        local result = {}
        for key, value in pairs(capability) do result[key] = value end
        result.missingPackages, result.parity = Json.array({}), "unverified"
        for _, package in ipairs(capability.packages) do if not installed[package] then result.missingPackages[#result.missingPackages + 1] = package end end
        report.capabilities[#report.capabilities + 1] = result
    end
    return report
end

return Assessment
