-- How notifications look and behave (the colours, border and rounded shape
-- come from the theme: notification_* in themes/base.lua). Critical ones stay
-- until clicked and get a red border; low-urgency ones are dimmed and short
local naughty = require("naughty")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi

local p = beautiful.palette or {}

naughty.config.padding = dpi(8) -- from the screen edge
naughty.config.spacing = dpi(6) -- between notifications

local defaults = naughty.config.defaults
defaults.position = "top_right"
defaults.timeout = 6
defaults.margin = dpi(10)
defaults.border_width = dpi(1)

-- Changed in place: notify-send's urgency levels are mapped to these very
-- tables (naughty.dbus.config.mapping), so replacing them would bypass this
local presets = naughty.config.presets
local function set(preset, values)
	for k, v in pairs(values) do
		preset[k] = v
	end
end
set(presets.low, { timeout = 4, fg = p.fg_dim, border_color = p.surface })
set(presets.critical, { timeout = 0, bg = p.bg, fg = p.fg, border_color = p.red, border_width = dpi(2) })
