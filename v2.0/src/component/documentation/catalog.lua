local File = require("core.file")
local Json = require("core.json")
local Documentation = {}
Documentation.__index = Documentation

function Documentation.new(root, process, policy)
    return setmetatable({root=root, process=process, policy=policy}, Documentation)
end

function Documentation:report()
    local policy = self.policy
    local directory = self.root .. "/" .. policy.directory
    local shared, documents = {}, {}
    for _, name in ipairs(policy.sharedNames) do shared[name] = true end
    local report = {complete=true, documents=Json.array({}), missing=Json.array({}), identical=Json.array({}), languages=policy.languages}
    for _, language in ipairs(policy.languages) do
        local source = directory .. "/" .. language
        local listing = self.process:run("runtimeFiles", {source, "-type", "f", "-name", policy.pattern, "-print0"})
        for path in listing:gmatch("[^%z]+") do
            if not shared[path:match("([^/]+)$")] then documents[path:sub(#source + 2)] = true end
        end
    end
    for relative in pairs(documents) do
        report.documents[#report.documents + 1] = relative
        local contents = {}
        for _, language in ipairs(policy.languages) do
            local translated = directory .. "/" .. language .. "/" .. relative
            local file, failure, code = io.open(translated, "rb")
            if file then
                local content = assert(file:read("a")); assert(file:close())
                assert(content:match("^# [^\n]+"), "missing_document_title_" .. translated)
                contents[language] = content
            else
                assert(code == 2, failure)
                report.missing[#report.missing + 1] = translated; report.complete = false
            end
        end
        for _, language in ipairs(policy.languages) do
            if language ~= policy.sourceLanguage and contents[language] and contents[language] == contents[policy.sourceLanguage] then
                report.identical[#report.identical + 1] = directory .. "/" .. language .. "/" .. relative
                report.complete = false
            end
        end
    end
    assert(#report.documents > 0, "empty_documentation_catalogue")
    table.sort(report.documents); table.sort(report.missing); table.sort(report.identical)
    return report
end

return Documentation
