-- Shared pieces for the bar widgets: a glyph + text item coloured by status,
-- a themed detail popup, and helpers for the key=value status scripts
local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi

local settings = require("config.settings")

local common = {}

common.escape = gears.string.xml_escape

-- color returns the palette colour for a status level
function common.color(level)
	local p = beautiful.palette or {}
	return ({
		ok = p.green,
		warn = p.yellow,
		bad = p.red,
		dim = p.fg_dim,
		accent = p.accent,
	})[level] or beautiful.fg_normal
end

-- span wraps text in a Pango colour span for level
function common.span(level, text)
	return string.format('<span foreground="%s">%s</span>', common.color(level), text)
end

-- num wraps text in tabular digits: every digit gets the same width, so a
-- number that changes doesn't make the bar shift
function common.num(text)
	return '<span font_features="tnum">' .. text .. "</span>"
end

-- FIGURE_SPACE is exactly as wide as a tabular digit
common.FIGURE_SPACE = utf8.char(0x2007)

-- pad left-pads text with figure spaces to width characters, so "8%" takes
-- the same room as "100%" once wrapped in num()
function common.pad(text, width)
	local missing = width - utf8.len(text)
	return missing > 0 and string.rep(common.FIGURE_SPACE, missing) .. text or text
end

-- fixed_text returns a right-aligned textbox exactly as wide as the widest of
-- the given template markups (e.g. num("100%")), so a value that changes
-- width ("83K" -> "1.2M") never makes the bar shift
function common.fixed_text(...)
	local textbox = wibox.widget.textbox()
	local width = 0
	for _, template in ipairs({ ... }) do
		textbox.markup = template
		width = math.max(width, (textbox:get_preferred_size(screen.primary)))
	end
	textbox.markup = ""
	textbox.forced_width = width
	textbox.align = "right"
	return textbox
end

-- item_markup is what a bar_item shows for a glyph and text (text optional)
function common.item_markup(glyph, text, level)
	local markup = common.span(level, glyph)
	if text and text ~= "" then
		markup = markup .. " " .. common.span(level == "bad" and "bad" or nil, common.num(common.escape(text)))
	end
	return markup
end

-- bar_item returns a bar widget showing a glyph and short text, with
-- :update(glyph, text, level). Its text uses tabular digits (see num)
-- Given width templates (glyph/text pairs as passed to update), the item is
-- fixed to the widest of them (see fixed_text)
function common.bar_item(...)
	local textbox = select("#", ...) > 0 and common.fixed_text(...) or wibox.widget.textbox()
	local item = wibox.widget({
		textbox,
		left = dpi(6),
		right = dpi(6),
		widget = wibox.container.margin,
	})

	function item:update(glyph, text, level)
		textbox.markup = common.item_markup(glyph, text, level)
	end

	return item
end

-- popup returns an empty themed awful.popup around widget (rounded, bordered,
-- on top, hidden). The detail popups and the clickable panels both use it
local function popup(widget)
	return awful.popup({
		widget = { widget, margins = dpi(10), widget = wibox.container.margin },
		bg = beautiful.bg_normal,
		fg = beautiful.fg_normal,
		border_color = beautiful.palette and beautiful.palette.surface or beautiful.border_focus,
		border_width = dpi(1),
		shape = function(cr, w, h)
			gears.shape.rounded_rect(cr, w, h, dpi(8))
		end,
		ontop = true,
		visible = false,
	})
end

-- place puts p under the widget at geometry (mouse.current_widget_geometry),
-- or at the top right when there is none (opened from awesome-client). The
-- placement property is re-applied once p has measured its content
local function place(p, geometry)
	if geometry then
		p.placement = nil
		p:move_next_to(geometry)
	else
		p.placement = function(d)
			return awful.placement.top_right(d, { margins = { top = beautiful.wibar_height + dpi(4), right = dpi(4) } })
		end
	end
end

-- attach_popup shows a themed popup next to item while hovered; a left click
-- pins it open until the next click. build() returns the popup's Pango markup
function common.attach_popup(item, build)
	local textbox = wibox.widget({ font = settings.font_mono, widget = wibox.widget.textbox })
	local p = popup(textbox)
	local pinned = false

	local function show()
		textbox.markup = build()
		place(p, mouse.current_widget_geometry)
		p.visible = true
	end

	item:connect_signal("mouse::enter", show)
	item:connect_signal("mouse::leave", function()
		if not pinned then
			p.visible = false
		end
	end)
	item:buttons(gears.table.join(item:buttons(), awful.button({}, 1, function()
		pinned = not pinned
		if pinned then
			show()
		else
			p.visible = false
		end
	end)))

	item.show_popup = show
	item.popup = p

	-- refresh the content if it changes while open
	function item:refresh_popup()
		if p.visible then
			textbox.markup = build()
		end
	end

	return p
end

-- {{{ Panels: the clickable popups of the volume and VPN widgets

-- panel returns a themed popup around content (usually a vertical layout).
-- panel:show_at(geometry) opens it under the clicked widget; it closes when
-- the mouse leaves it
function common.panel(content)
	local p = popup(content)
	function p:show_at(geometry)
		place(p, geometry)
		p.visible = true
	end
	p:connect_signal("mouse::leave", function()
		p.visible = false
	end)
	return p
end

-- heading returns a bold section title for a panel; first = true for the
-- topmost one, which gets no space above it
function common.heading(text, first)
	return wibox.widget({
		{ markup = "<b>" .. common.escape(text) .. "</b>", widget = wibox.widget.textbox },
		top = first and 0 or dpi(8),
		bottom = dpi(2),
		widget = wibox.container.margin,
	})
end

-- row returns a padded panel row showing markup. With on_click it highlights
-- on hover and runs on_click when clicked
function common.row(markup, on_click)
	local bg = wibox.widget({
		{
			{ markup = markup, widget = wibox.widget.textbox },
			left = dpi(6),
			right = dpi(6),
			top = dpi(3),
			bottom = dpi(3),
			widget = wibox.container.margin,
		},
		shape = function(cr, w, h)
			gears.shape.rounded_rect(cr, w, h, dpi(4))
		end,
		widget = wibox.container.background,
	})
	if on_click then
		bg:connect_signal("mouse::enter", function()
			bg.bg = beautiful.bg_focus
		end)
		bg:connect_signal("mouse::leave", function()
			bg.bg = nil
		end)
		bg:buttons(awful.button({}, 1, on_click))
	end
	return bg
end
-- }}}

-- parse_kv turns "key=value" lines into a table; repeated keys become lists
-- under the same name
function common.parse_kv(stdout)
	local data = {}
	for key, value in stdout:gmatch("([%w_]+)=([^\n]*)") do
		if data[key] == nil then
			data[key] = value
		elseif type(data[key]) == "table" then
			table.insert(data[key], value)
		else
			data[key] = { data[key], value }
		end
	end
	return data
end

-- list returns a parse_kv value as a list, whether it appeared once or more
function common.list(value)
	if value == nil then
		return {}
	end
	return type(value) == "table" and value or { value }
end

-- time parses "YYYY-MM-DD HH:MM:SS" (local time) into os.time
function common.time(s)
	local y, mo, d, h, mi, se = (s or ""):match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
	if not y then
		return nil
	end
	return os.time({ year = y, month = mo, day = d, hour = h, min = mi, sec = se })
end

-- ago formats a number of seconds as a short age: 45s, 12m, 5h, 21d
function common.ago(seconds)
	if not seconds then
		return "?"
	end
	if seconds < 60 then
		return math.floor(seconds) .. "s"
	elseif seconds < 3600 then
		return math.floor(seconds / 60) .. "m"
	elseif seconds < 86400 * 2 then
		return math.floor(seconds / 3600) .. "h"
	end
	return math.floor(seconds / 86400) .. "d"
end

-- watch runs a status script now and every interval seconds, passing the
-- parsed output to callback. Returns a function that runs it again right away
function common.watch(script, interval, callback)
	local path = gears.filesystem.get_configuration_dir() .. "scripts/" .. script
	local function run()
		awful.spawn.easy_async({ path }, function(stdout)
			callback(common.parse_kv(stdout))
		end)
	end
	gears.timer({ timeout = interval, autostart = true, call_now = true, callback = run })
	return run
end

-- watch_units checks every 10 s whether any of the given systemd user units
-- is running, and calls on_change when that flips: a backup or scan started
-- or finished. Cheap, so a run shorter than a widget's full refresh interval
-- still shows up right away
function common.watch_units(units, on_change)
	local cmd = { "systemctl", "--user", "is-active" }
	for _, unit in ipairs(units) do
		table.insert(cmd, unit)
	end
	local was_running
	gears.timer({
		timeout = 10,
		autostart = true,
		call_now = true,
		callback = function()
			awful.spawn.easy_async(cmd, function(stdout)
				-- a oneshot service is "activating" while it runs
				local running = false
				for state in stdout:gmatch("[^\n]+") do
					if state == "activating" or state == "active" then
						running = true
					end
				end
				if was_running ~= nil and running ~= was_running then
					on_change(running)
				end
				was_running = running
			end)
		end,
	})
end

-- menu shows an awful.menu of items at the mouse, replacing one already open.
-- Called again by the same widget while its menu is open, it closes it
-- instead, so a second right click on an icon dismisses the menu (Escape
-- still works too). The widget is told apart by its file, so callers just
-- pass the items
function common.menu(items)
	local owner = debug.getinfo(2, "S").source
	local open = common.open_menu
	-- visible now, i.e. not already closed by Escape or by picking an item
	local was_open = open ~= nil and open.wibox.visible
	if open then
		open:hide()
		common.open_menu = nil
	end
	if was_open and open.owner == owner then
		return -- same icon again: just close it
	end
	common.open_menu = awful.menu({ items = items, theme = { width = dpi(220) } })
	common.open_menu.owner = owner
	common.open_menu:show()
end

return common
