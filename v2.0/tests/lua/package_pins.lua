return function(suite)
    local Pins = require("component.package.pins")
    local function check(output, status)
        return Pins.new({
            run = function()
                assert(status == 0, "pacman_conf_failed")
                return output
            end,
        }, { updateableRetained = { "nautilus", "brave-origin-bin" } }):retained_updateable()
    end
    suite:test("unrelated package pins keep retained apps updateable", function()
        assert(check("linux-lts custom-hold\n", 0))
    end)
    suite:test("exact retained package pin is rejected", function()
        assert(not check("nautilus\n", 0))
    end)
    suite:test("wildcard retained package pin is rejected", function()
        assert(not check("brave-*\n", 0))
    end)
    suite:test("empty package pins keep retained apps updateable", function()
        assert(check("", 0))
    end)
    suite:test("pacman configuration failure propagates", function()
        suite:reject(function()
            check("", 42)
        end)
    end)
end
