local root, destination, done = assert(arg[1]), assert(arg[2]), assert(arg[3])
package.path = root .. "/src/?.lua;" .. package.path
local ok, failure = pcall(function()
    local File = require("core.file")
    local process = require("core.process").new(File.json(root .. "/data/core/commands.json"))
    local publisher = require("core.publisher").new(process)
    for index = 1, 100 do publisher:publish(destination, (index % 2 == 0 and "a" or "b"):rep(131072), "600") end
end)
local file = assert(io.open(done, "w")); assert(file:write(ok and "complete" or tostring(failure))); assert(file:close())
if not ok then error(failure) end
