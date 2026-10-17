local Interface = {}
Interface.__index = Interface

function Interface.new(root, process, catalog, policy, locale, output, input)
    return setmetatable({
        root = root,
        process = process,
        catalog = catalog,
        policy = policy,
        locale = locale,
        output = output or io.stdout,
        input = input or io.stdin,
    }, Interface)
end

function Interface:help()
    self.output:write(self.catalog:text("app.title"), "\n\n")
    for _, row in ipairs(self.policy.help) do
        self.output:write(self.policy.rowFormat:format(row.target, self.catalog:text(row.key)))
    end
    self.output:write("\n", self.catalog:text("locale.supported", table.concat(self.locale.languages, " ")), "\n")
    self.output:write(self.catalog:text("locale.language_active", self.catalog.language), "\n")
    return 0
end

function Interface:languages()
    self.output:write(self.catalog:text("i18n.available"), "\n")
    for _, language in ipairs(self.locale.languages) do
        if language == self.catalog.language then
            self.output:write(self.policy.activeLanguageFormat:format(language, self.catalog:text("i18n.current")))
        else
            self.output:write(self.policy.languageFormat:format(language))
        end
    end
    return 0
end

function Interface:locale_status()
    local count = 0
    for _ in pairs(self.catalog.messages) do
        count = count + 1
    end
    self.output:write(
        self.policy.localeStatusFormat:format(self.catalog.language, self.root .. "/" .. self.policy.catalog, count)
    )
    return 0
end

function Interface:launch(mode, arguments)
    local policy, command = self.policy, self.policy.privilegedCommand
    local values = {}
    assert(#arguments <= (mode == "project-keyring" and 1 or 0), "invalid_project_launch_arguments")
    if mode == "project-keyring" then
        local backend = arguments[1]
        if not backend or backend == "" then backend = policy.defaultKeyring end
        local accepted = false
        for _, allowed in ipairs(policy.keyrings) do
            if backend == allowed then accepted = true end
        end
        assert(accepted, self.catalog:text("keyring.backend_invalid", backend))
        command = policy.keyringCommand
        values = { policy.keyringVariable .. "=" .. backend }
        for _, word in ipairs(self.process.commands[policy.directCommand]) do
            values[#values + 1] = word
        end
    elseif mode == "project-entry" then
        assert(self.process:run("identity"):match("^0%s*$"), self.catalog:text("__root_required"))
        command = policy.directCommand
        self.output:write(self.catalog:text("app.title"), "\n", self.catalog:text("setup.entrypoint"), "\n")
    elseif mode == "project-run-setup" then
        self.output:write(self.catalog:text("__log_in_progress", self.root .. "/" .. policy.log), "\n\n")
    else
        assert(mode == "project-launch", "unknown_project_launch_mode")
    end
    local pipeline = self.root .. "/" .. policy.pipeline
    local file = assert(io.open(pipeline, "rb"), self.catalog:text("__pipeline_missing"))
    assert(file:close())
    values[#values + 1] = pipeline
    local status = self.process:status(command, values)
    if status ~= 0 then return status end
    if mode == "project-launch" then
        self.output:write(self.catalog:text("__press_enter"))
        if self.input:read("l") == nil then return 1 end
    end
    return 0
end

return Interface
