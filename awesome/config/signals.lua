-- Client signals: placement on manage, titlebars (floating windows only),
-- focus borders
local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")

local settings = require("config.settings")

-- Signal function to execute when a new client appears.
client.connect_signal("manage", function(c)
	-- Set the windows at the slave,
	-- i.e. put it at the end of others instead of setting it master.
	-- if not awesome.startup then awful.client.setslave(c) end

	if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then
		-- Prevent clients from being unreachable after screen count changes.
		awful.placement.no_offscreen(c)
	end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
	local buttons = gears.table.join(
		awful.button({}, 1, function()
			c:emit_signal("request::activate", "titlebar", { raise = true })
			awful.mouse.client.move(c)
		end),
		awful.button({}, 3, function()
			c:emit_signal("request::activate", "titlebar", { raise = true })
			awful.mouse.client.resize(c)
		end)
	)

	awful.titlebar(c, { size = settings.titlebar.height }):setup({
		{ -- Left
			awful.titlebar.widget.iconwidget(c),
			buttons = buttons,
			layout = wibox.layout.fixed.horizontal,
		},
		{ -- Middle
			{ -- Title
				align = "center",
				font = settings.titlebar.font,
				widget = awful.titlebar.widget.titlewidget(c),
			},
			buttons = buttons,
			layout = wibox.layout.flex.horizontal,
		},
		{ -- Right
			awful.titlebar.widget.floatingbutton(c),
			awful.titlebar.widget.maximizedbutton(c),
			awful.titlebar.widget.stickybutton(c),
			awful.titlebar.widget.ontopbutton(c),
			awful.titlebar.widget.closebutton(c),
			layout = wibox.layout.fixed.horizontal(),
		},
		layout = wibox.layout.align.horizontal,
	})
	c.has_titlebar = true
	c:emit_signal("titlebar::update")
end)

-- Titlebars only where they help: floating windows, dialogs, and anything on
-- a tag using the floating layout. Tiled windows have none. The rules build
-- them for every normal window and dialog; this shows or hides them
local function update_titlebar(c)
	if not c.has_titlebar then
		return -- e.g. the scratchpad terminal, which never gets one
	end
	local t = c.first_tag
	if c.floating or c.type == "dialog" or (t and t.layout == awful.layout.suit.floating) then
		awful.titlebar.show(c)
	else
		awful.titlebar.hide(c)
	end
end

client.connect_signal("manage", update_titlebar)
client.connect_signal("titlebar::update", update_titlebar)
client.connect_signal("property::floating", update_titlebar)
client.connect_signal("tagged", update_titlebar)
tag.connect_signal("property::layout", function(t)
	for _, c in ipairs(t:clients()) do
		update_titlebar(c)
	end
end)

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
	c:emit_signal("request::activate", "mouse_enter", { raise = false })
end)

client.connect_signal("focus", function(c)
	c.border_color = beautiful.border_focus
end)
client.connect_signal("unfocus", function(c)
	c.border_color = beautiful.border_normal
end)
