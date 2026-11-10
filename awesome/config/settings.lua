-- The one place to tweak: programs, keys and layouts
local gears = require("gears")
local awful = require("awful")

local settings = {}

settings.terminal = "kitty"
settings.editor = os.getenv("EDITOR") or "editor"
settings.editor_cmd = settings.terminal .. " -e " .. settings.editor

-- Theme: a file in themes/ or a palette in themes/palettes/ (see the
-- Themes menu, or scripts/preview-themes.sh to compare them)
settings.theme = "gruvbox_dark"
settings.font = "Fira Sans 10"
settings.font_mono = "Fira Mono 10" -- widget popups, so columns line up

-- Top bar and window titlebar sizes, in pixels so they're the same on every
-- monitor. (awesome's DPI here is 161, from the 4K panel, so sizes scaled with
-- dpi() came out ~1.7x too big on the 1440p and 1080p monitors)
settings.bar_height = 30
settings.titlebar = { height = 26, font = "Fira Sans 9" }

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
settings.modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
settings.layouts = {
	awful.layout.suit.fair,
	awful.layout.suit.fair.horizontal,
	awful.layout.suit.tile,
	awful.layout.suit.tile.bottom,
	awful.layout.suit.max,
	awful.layout.suit.magnifier,
	awful.layout.suit.floating,
}

-- Per monitor, by xrandr output name: the default layout of its tags, its
-- wallpaper (a file in backgrounds/) and optional tag names (tags = {...}).
-- Keyed by name, not screen number, because awesome numbers the screens
-- differently from one restart to the next
settings.backgrounds = gears.filesystem.get_configuration_dir() .. "backgrounds/"
settings.screens = {
	["HDMI-0"] = {
		layout = awful.layout.suit.fair,
		wallpaper = "iceland-mountain-road.JPG",
		-- tags = { "dev", "web", "db" }, -- names for tags 1, 2, 3...; the rest stay numbers
	},
	["DP-4"] = { layout = awful.layout.suit.fair, wallpaper = "iceland-sunset.JPG" },
	["DP-2"] = { layout = awful.layout.suit.fair, wallpaper = "iceland-long-road.JPG" },
	["DP-1"] = { layout = awful.layout.suit.fair.horizontal, wallpaper = "iceland-waterfall.JPG" },
}
-- for any other monitor
settings.screen_default = { layout = awful.layout.suit.fair }
-- the monitor whose bar has the status widgets and the tray (the primary when
-- this one isn't connected)
settings.bar_output = "HDMI-0"

-- Colour temperature through the day, { from hour, kelvin }, and brightness,
-- both applied with xsct by modules/idle_dim.lua. The screens dim to
-- brightness.idle after idle_timeout seconds without input, unless media is
-- playing (playerctl). Mod+F11/F12 shift the temperature, Mod+F10 resets it
settings.temperature = {
	{ 2, 3000 },
	{ 6, 3000 },
	{ 8, 4250 },
	{ 10, 5500 },
	{ 12, 6500 },
	{ 14, 5500 },
	{ 16, 4250 },
	{ 18, 3000 },
	{ 21, 3000 },
	{ 22, 3000 },
}
settings.brightness = { day = 1.0, night = 0.5, idle = 0.1, day_from = 6, night_from = 21 }
settings.idle_timeout = 300
-- while idle: a black overlay with a big clock on this monitor
-- (modules/idle_clock.lua), kept at this brightness so the time is readable
settings.idle_clock = { output = "HDMI-0", brightness = 0.3 }

-- Proton VPN widget (widgets/vpn.lua): countries in its right-click menu, as
-- `protonvpn connect --country` takes them (a code like US, or a full name)
settings.vpn = { countries = { "US", "CA", "CH", "NL" } }

-- Volume widget (widgets/volume.lua): how far volume can go, like pavucontrol's
-- boost (scroll, keys and every slider stop here), the scroll/key step, and
-- short names for outputs (matched as part of the output's full name)
settings.volume = {
	max = 150, -- percent
	step = 5, -- percent
	names = { ["Pebble V3"] = "Speakers", ["JBL Quantum810"] = "Headphones", ["HDMI"] = "HDMI", ["IEC958"] = "Optical" },
}

return settings
