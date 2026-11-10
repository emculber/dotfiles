-- Things to run once per X session (each login), not on every Mod+Ctrl+r. An X
-- root-window property marks the session as done: it survives awesome
-- restarts and is gone after logout or reboot. AWESOME_NO_AUTOSTART (set by the
-- Xephyr test scripts) skips it
local gears = require("gears")
local awful = require("awful")
local naughty = require("naughty")

local autostart = {}

local MARK = "awesome.autostart.done"
awesome.register_xproperty(MARK, "boolean")

local scripts = gears.filesystem.get_configuration_dir() .. "scripts/"

-- display_setup applies the monitor layout and turns off blanking/DPMS
function autostart.display_setup()
	awful.spawn.easy_async({ scripts .. "display-setup.sh" }, function(_, stderr, _, code)
		if code ~= 0 then
			naughty.notify({
				preset = naughty.config.presets.critical,
				title = "display-setup.sh failed",
				text = stderr,
			})
		end
	end)
end

if not os.getenv("AWESOME_NO_AUTOSTART") and not awesome.get_xproperty(MARK) then
	awesome.set_xproperty(MARK, true)
	autostart.display_setup()
end

return autostart
