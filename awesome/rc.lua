-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

-- awesome 4.3 on newer GLib: must come before awful is used
require("modules.compat")

local awful = require("awful")
require("awful.autofocus")
local naughty = require("naughty")

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
	naughty.notify({
		preset = naughty.config.presets.critical,
		title = "Oops, there were errors during startup!",
		text = awesome.startup_errors,
	})
end

-- Handle runtime errors after startup
do
	local in_error = false
	awesome.connect_signal("debug::error", function(err)
		-- Make sure we don't go into an endless error loop
		if in_error then
			return
		end
		in_error = true

		naughty.notify({
			preset = naughty.config.presets.critical,
			title = "Oops, an error happened!",
			text = tostring(err),
		})
		in_error = false
	end)
end
-- }}}

local settings = require("config.settings")
awful.layout.layouts = settings.layouts

-- Themes define colours, icons and fonts (themes/, modules/theme_switcher.lua)
require("modules.theme_switcher").init()

-- scripts/test-xephyr.sh: fake monitors inside the test window
if os.getenv("AWESOME_FAKE_SCREENS") then
	require("modules.fake_screens")
end

-- Order matters: each module requires the ones it builds on
require("config.menu")
require("config.buttons")
require("config.keys")
require("config.screens")
require("config.rules")
require("config.signals")
require("config.notifications")

-- Extras: if one fails it shows an error instead of taking the config down
local function optional(name)
	local ok, err = pcall(require, name)
	if not ok then
		naughty.notify({ preset = naughty.config.presets.critical, title = name .. " failed to load", text = tostring(err) })
	end
end

optional("config.autostart")
optional("modules.idle_clock") -- before idle_dim, so it hears the first dim
optional("modules.idle_dim")
