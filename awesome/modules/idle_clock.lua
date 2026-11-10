-- While the screens are idle-dimmed (modules/idle_dim.lua), a black overlay
-- with a large clock and the date covers one monitor: settings.idle_clock.output
-- (the primary screen when that monitor isn't there, e.g. in Xephyr).
-- idle_dim keeps that monitor a little brighter so the time is readable. The
-- overlay goes away with the first input, when idle_dim undims
local wibox = require("wibox")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi

local settings = require("config.settings")
local persist = require("modules.persist")

local cfg = settings.idle_clock or {}
local p = beautiful.palette or {}

local function target_screen()
	for s in screen do
		if persist.output(s) == cfg.output then
			return s
		end
	end
	return screen.primary
end

local time = wibox.widget.textclock('<span font_features="tnum">%H:%M</span>', 1)
time.font = "Fira Sans Light 110"
time.align = "center"

local date = wibox.widget.textclock("%A, %B %e", 60)
date.font = "Fira Sans Light 26"
date.align = "center"

local overlay = wibox({
	ontop = true,
	visible = false,
	bg = "#000000",
	widget = wibox.widget({
		{
			{ time, fg = p.fg or beautiful.fg_normal, widget = wibox.container.background },
			{ date, fg = p.fg_dim or beautiful.fg_normal, widget = wibox.container.background },
			spacing = dpi(8),
			layout = wibox.layout.fixed.vertical,
		},
		valign = "center",
		halign = "center",
		widget = wibox.container.place,
	}),
})

local function show()
	local s = target_screen()
	overlay.screen = s
	overlay:geometry(s.geometry)
	overlay.visible = true
end

local function hide()
	overlay.visible = false
end

awesome.connect_signal("idle_dim::dimmed", show)
awesome.connect_signal("idle_dim::undimmed", hide)

return { show = show, hide = hide, overlay = overlay }
