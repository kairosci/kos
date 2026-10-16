local runtime = os.getenv("OMARCHY_PATH") or "/usr/share/omarchy"
dofile(runtime .. "/default/hypr/bootstrap.lua")
local config = os.getenv("OS_HYPR_CONFIG_ROOT") or ((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr")
package.path = config .. "/?.lua;" .. config .. "/../?.lua;" .. package.path
return {
  defaults = function() require("default.hypr.omarchy") end,
  toggles = function() require("default.hypr.toggles") end,
}
