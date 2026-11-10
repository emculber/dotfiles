-- Things to run once per X session (each login), not on every Mod+Ctrl+r. An X
-- root-window property marks the session as done: it survives awesome
-- restarts and is gone after logout or reboot. AWESOME_NO_AUTOSTART (set by the
-- Xephyr test scripts) skips it
local gears = require("gears")
local awful = require("awful")
local naughty = require("naughty")

local settings = require("config.settings")

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

-- {{{ Compositor (picom, scripts/picom.conf)
-- compositor_start starts picom unless it already runs, so a Mod+Ctrl+r never
-- makes a second one and a crashed one comes back
function autostart.compositor_start()
	awful.spawn.with_shell(
		"pgrep -x -u \"$USER\" picom >/dev/null || exec picom --config '" .. scripts .. "picom.conf'"
	)
end

-- compositor_stop stops picom, then calls after (if given)
function autostart.compositor_stop(after)
	awful.spawn.easy_async({ "pkill", "-x", "-u", os.getenv("USER"), "picom" }, function()
		if after then
			-- picom needs a moment to let go of the screen
			gears.timer.start_new(0.5, function()
				after()
				return false
			end)
		end
	end)
end

function autostart.compositor_restart()
	autostart.compositor_stop(autostart.compositor_start)
end

-- compositor_toggle turns picom off or on until the next Mod+Ctrl+r or login
function autostart.compositor_toggle()
	awful.spawn.easy_async({ "pgrep", "-x", "-u", os.getenv("USER"), "picom" }, function(_, _, _, code)
		if code == 0 then
			autostart.compositor_stop()
		else
			autostart.compositor_start()
		end
	end)
end
-- }}}

if not os.getenv("AWESOME_NO_AUTOSTART") then
	if not awesome.get_xproperty(MARK) then
		awesome.set_xproperty(MARK, true)
		autostart.display_setup()
	end
	-- every start, not only at login: it does nothing when picom already runs
	-- (and the menu's "compositor on/off" lasts until the next Mod+Ctrl+r)
	if settings.compositor then
		autostart.compositor_start()
	end
end

return autostart
