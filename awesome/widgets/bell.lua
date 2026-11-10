-- Notification bell: keeps the last 20 notifications from apps (notify-send,
-- Signal, Discord...) and shows a dot while any are unread. Click for the list
-- (opening it marks them read), right click for Do Not Disturb: app
-- notifications are then only listed, not shown, except critical ones.
-- awesome's own messages (volume, temperature) are never listed or held.
-- callback is naughty's notify_callback, installed by config/notifications.lua.
-- The list survives Mod+Ctrl+r and logins (~/.cache/awesome/notifications);
-- DND survives Mod+Ctrl+r but not a logout (an X root-window property)
local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local naughty = require("naughty")
local dpi = require("beautiful.xresources").apply_dpi

local common = require("widgets.common")

local KEEP = 20
local FILE = gears.filesystem.get_cache_dir() .. "notifications"
local DND = "awesome.dnd"
awesome.register_xproperty(DND, "boolean")

local GLYPH = {
	bell = utf8.char(0xf009a), -- nf-md-bell
	off = utf8.char(0xf009b), -- nf-md-bell_off
	dot = "●",
}

local bell = {}

local list = {} -- newest first: { time, app, title, text, unread }
local panel

-- {{{ Saving the list
local function clean(s)
	return ((s or ""):gsub("[\t\n\r]+", " "))
end

local function save()
	local f = io.open(FILE, "w")
	if not f then
		return
	end
	for _, n in ipairs(list) do
		f:write(n.time, "\t", n.unread and "1" or "0", "\t", clean(n.app), "\t", clean(n.title), "\t", clean(n.text), "\n")
	end
	f:close()
end

local function load()
	local f = io.open(FILE)
	if not f then
		return
	end
	for line in f:lines() do
		local time, unread, app, title, text = line:match("^(%d+)\t([01])\t([^\t]*)\t([^\t]*)\t(.*)$")
		if time and #list < KEEP then
			table.insert(list, { time = tonumber(time), unread = unread == "1", app = app, title = title, text = text })
		end
	end
	f:close()
end
-- }}}

local function unread()
	local count = 0
	for _, n in ipairs(list) do
		if n.unread then
			count = count + 1
		end
	end
	return count
end

function bell.dnd()
	return awesome.get_xproperty(DND) == true
end

-- {{{ The bar item
local textbox = common.fixed_text(common.span(nil, GLYPH.bell .. GLYPH.dot))
textbox.align = "center"
local item = wibox.widget({ textbox, left = dpi(6), right = dpi(6), widget = wibox.container.margin })
local tooltip = awful.tooltip({ objects = { item }, mode = "outside" })

-- render_bar redraws the bell; render also redraws an open panel
local function render_bar()
	local count = unread()
	if bell.dnd() then
		textbox.markup = common.span("dim", GLYPH.off) .. (count > 0 and common.span("accent", GLYPH.dot) or "")
	else
		textbox.markup = common.span(nil, GLYPH.bell) .. (count > 0 and common.span("accent", GLYPH.dot) or "")
	end
	tooltip.text = string.format(
		"%s%s",
		count > 0 and (count .. " unread") or "No unread notifications",
		bell.dnd() and "\nDo Not Disturb is on" or ""
	)
end

local function render()
	render_bar()
	if panel and panel.visible then
		panel:sync()
	end
end
-- }}}

-- callback sees every naughty.notify. App notifications (they come over D-Bus
-- with freedesktop hints) are listed, and held back while DND is on unless
-- critical. Returning nil drops the popup
function bell.callback(args)
	if not args.freedesktop_hints then
		return args -- awesome's own messages
	end
	local now = os.time()
	local app, title, text = args.appname or "", args.title or "", args.text or ""
	local newest = list[1]
	if newest and newest.app == app and newest.title == title and now - newest.time < 60 then
		-- the same notification updated (a track change, a download): one entry
		newest.text, newest.time, newest.unread = text, now, true
	else
		table.insert(list, 1, { time = now, app = app, title = title, text = text, unread = true })
		while #list > KEEP do
			table.remove(list)
		end
	end
	save()
	-- naughty calls this before showing it; redraw after this returns
	gears.timer.delayed_call(render)

	-- urgency arrives as a byte: "\0" low, "\1" normal, "\2" critical
	local critical = args.freedesktop_hints.urgency == "\2"
	if bell.dnd() and not critical then
		return nil
	end
	return args
end

function bell.toggle_dnd()
	awesome.set_xproperty(DND, not bell.dnd())
	render()
	naughty.notify({
		title = "Do Not Disturb",
		text = bell.dnd() and "on: app notifications are only listed under the bell" or "off",
		timeout = 2,
	})
end

function bell.clear()
	list = {}
	save()
	render()
end

-- {{{ The panel
local function when(t)
	if os.date("%Y-%m-%d", t) == os.date("%Y-%m-%d") then
		return os.date("%H:%M", t)
	end
	return os.date("%a %H:%M", t)
end

local function trim(s, n)
	s = clean(s)
	if utf8.len(s) and utf8.len(s) > n then
		return s:sub(1, utf8.offset(s, n) - 1) .. "…"
	end
	return s
end

local function build_panel()
	local rows = wibox.layout.fixed.vertical()
	local p = common.panel({
		common.heading("Notifications", true),
		rows,
		layout = wibox.layout.fixed.vertical,
	})

	function p:sync()
		rows:reset()
		if #list == 0 then
			rows:add(common.row(common.span("dim", "Nothing yet")))
		end
		for _, n in ipairs(list) do
			local head = common.span("dim", common.num(when(n.time)) .. "  ")
				.. (n.app ~= "" and ("<b>" .. common.escape(trim(n.app, 20)) .. "</b>  ") or "")
				.. common.escape(trim(n.title, 50))
			local body = n.text ~= "" and ("\n" .. common.span("dim", common.escape(trim(n.text, 70)))) or ""
			rows:add(common.row((n.unread and common.span("accent", "● ") or "   ") .. head .. body))
		end
		rows:add(wibox.widget({
			common.row(common.span("dim", bell.dnd() and "Do Not Disturb: on (right-click the bell)" or "Do Not Disturb: off (right-click the bell)")),
			top = dpi(6),
			widget = wibox.container.margin,
		}))
		if #list > 0 then
			rows:add(common.row(common.span("warn", "Clear"), bell.clear))
		end
	end

	return p
end

local function toggle_panel()
	panel = panel or build_panel()
	if panel.visible then
		panel.visible = false
		return
	end
	panel:sync() -- still shows which were unread
	panel:show_at(mouse.current_widget_geometry)
	for _, n in ipairs(list) do
		n.unread = false
	end
	save()
	render_bar()
end
-- }}}

item:buttons(gears.table.join(awful.button({}, 1, toggle_panel), awful.button({}, 3, bell.toggle_dnd)))

load()
render()

bell.widget = item

return bell
