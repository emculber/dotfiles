-- Per-screen setup: wallpaper, tags and the wibar
local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local naughty = require("naughty")

local settings = require("config.settings")
local menu = require("config.menu")
local buttons = require("config.buttons")
local persist = require("modules.persist")

-- Create a textclock widget
-- (tabular digits, so the ticking seconds don't make the bar shift)
local textclock = wibox.widget.textclock('<span font_features="tnum">%Y-%m-%d %H:%M:%S</span>', 1)

local month_calendar = awful.widget.calendar_popup.month()
month_calendar:attach(textclock, "tr")

-- Status widgets for the main monitor's bar. One that fails to load is left
-- out with an error notification, so the bar still comes up
local status_widgets = {}
for _, name in ipairs({
	"widgets.nowplaying",
	"widgets.sysinfo",
	"widgets.gpu",
	"widgets.backup",
	"widgets.clamav",
	"widgets.vpn",
	"widgets.i2p",
	"widgets.volume",
	"widgets.nightlight",
	"widgets.claude",
	"widgets.bell",
}) do
	local ok, widget = pcall(require, name)
	if ok then
		table.insert(status_widgets, widget.widget)
	else
		naughty.notify({ preset = naughty.config.presets.critical, title = name .. " failed to load", text = tostring(widget) })
	end
end

-- is_bar_screen says whether s gets the full bar (status widgets and tray):
-- the monitor settings.bar_output names, or the primary when that one isn't
-- connected. By name, because at login the bars are built before
-- display-setup.sh makes HDMI-0 primary
local function is_bar_screen(s)
	for other in screen do
		if persist.output(other) == settings.bar_output then
			return other == s
		end
	end
	return s == screen.primary
end

-- one tray, pinned to the full bar's screen (in 4.3 it follows the primary)
local systray = wibox.widget.systray()

-- screen_settings returns the settings.screens entry for screen s's monitor
local function screen_settings(s)
	return settings.screens[persist.output(s)] or settings.screen_default
end

-- rotating or fixed, cropped to fill (modules/wallpaper.lua)
local function set_wallpaper(s)
	require("modules.wallpaper").apply(s)
end

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)

awful.screen.connect_for_each_screen(function(s)
	set_wallpaper(s)

	-- Each screen has its own 9 tags, named from settings.screens[output].tags
	-- ("1:dev"), or just the number. Mod+Shift+r renames one on the fly
	local names = screen_settings(s).tags or {}
	local labels = {}
	for i = 1, 9 do
		labels[i] = names[i] and (i .. ":" .. names[i]) or tostring(i)
	end
	awful.tag(labels, s, screen_settings(s).layout)
	for _, t in ipairs(s.tags) do
		t.default_name = t.name
	end
	persist.restore_tags(s)

	-- Create a promptbox for each screen
	s.mypromptbox = awful.widget.prompt()
	-- Create an imagebox widget which will contain an icon indicating which layout we're using.
	-- We need one layoutbox per screen.
	s.mylayoutbox = awful.widget.layoutbox(s)
	s.mylayoutbox:buttons(gears.table.join(
		awful.button({}, 1, function()
			awful.layout.inc(1)
		end),
		awful.button({}, 3, function()
			awful.layout.inc(-1)
		end),
		awful.button({}, 4, function()
			awful.layout.inc(1)
		end),
		awful.button({}, 5, function()
			awful.layout.inc(-1)
		end)
	))

	s.mytaglist = awful.widget.taglist({
		screen = s,
		filter = awful.widget.taglist.filter.all,
		buttons = buttons.taglist,
	})

	s.mytasklist = awful.widget.tasklist({
		screen = s,
		filter = awful.widget.tasklist.filter.currenttags,
		buttons = buttons.tasklist,
	})

	s.mywibox = awful.wibar({ position = "top", screen = s })

	local right = { layout = wibox.layout.fixed.horizontal }
	if is_bar_screen(s) then
		for _, widget in ipairs(status_widgets) do
			table.insert(right, widget)
		end
		systray:set_screen(s)
		table.insert(right, systray)
	end
	table.insert(right, textclock)
	table.insert(right, s.mylayoutbox)

	s.mywibox:setup({
		layout = wibox.layout.align.horizontal,
		{ -- Left widgets
			layout = wibox.layout.fixed.horizontal,
			menu.launcher,
			s.mytaglist,
			s.mypromptbox,
		},
		s.mytasklist, -- Middle widget
		right,
	})
end)
