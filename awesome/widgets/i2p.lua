-- I2P router in the bar: the I2P logo (widgets/icons/i2p.png, cut from the
-- router console's logo) tinted by status: green when the network is OK,
-- yellow when Firewalled or still starting, dim when the router is stopped.
-- Click turns the router on or off; hover for version, uptime, bandwidth and
-- tunnels; right click to open the console or restart it.
-- Data: scripts/i2p-status.sh every 30 s (pid file + the console sidebar)
local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local naughty = require("naughty")
local dpi = require("beautiful.xresources").apply_dpi

local common = require("widgets.common")

local ICON = gears.filesystem.get_configuration_dir() .. "widgets/icons/i2p.png"
local CONSOLE = "http://127.0.0.1:7657"
local FALLBACK_GLYPH = utf8.char(0xf059f) -- nf-md-web, if the PNG is missing

local i2p = {}

local data = {}

-- {{{ The bar item: the tinted logo, or a glyph without the PNG
local has_icon = gears.filesystem.file_readable(ICON)
local image = wibox.widget({ resize = true, widget = wibox.widget.imagebox })
local glyph = wibox.widget({ widget = wibox.widget.textbox })
local height = math.floor((beautiful.wibar_height or dpi(24)) * 0.62)
local item = wibox.widget({
	{
		has_icon and image or glyph,
		forced_height = height,
		forced_width = has_icon and math.floor(height * 56 / 64 + 0.5) or nil,
		valign = "center",
		widget = wibox.container.place,
	},
	left = dpi(6),
	right = dpi(6),
	widget = wibox.container.margin,
})

local function level()
	if data.running ~= "yes" then
		return "dim"
	elseif data.console ~= "up" then
		return "warn" -- starting
	elseif data.network == "OK" then
		return "ok"
	end
	return "warn" -- Firewalled, Testing, ...
end

local shown_level
local function render()
	local lv = level()
	if lv ~= shown_level then
		shown_level = lv
		if has_icon then
			-- recolor_image paints in place, so start from a fresh copy
			image.image = gears.color.recolor_image(gears.surface.load_uncached(ICON), common.color(lv))
		else
			glyph.markup = common.span(lv, FALLBACK_GLYPH)
		end
	end
	item:refresh_popup()
end
-- }}}

-- {{{ The hover popup
local function popup()
	if data.running ~= "yes" then
		return "<b>I2P</b>  stopped\n\nClick to turn it on"
	end
	if data.console ~= "up" then
		return "<b>I2P</b>  starting (the console isn't answering yet)"
	end
	local tunnels = common.list(data.tunnel)
	local lines = {
		"<b>I2P</b>  " .. common.escape(data.version or "?"),
		"Uptime    " .. common.escape(data.uptime or "?"),
		"Network   " .. common.span(level(), common.escape(data.network or "?")),
	}
	if data.network == "Firewalled" then
		table.insert(lines, common.span("dim", "          other routers can't reach this one: forward the I2P port"))
		table.insert(lines, common.span("dim", "          (console → Network) on the home router to fix it"))
	end
	table.insert(lines, "3 s       " .. common.escape(data.bw3s or "?") .. "  (in / out)")
	table.insert(lines, "5 min     " .. common.escape(data.bw5m or "?"))
	table.insert(lines, "Used      " .. common.escape(data.used or "?"))
	table.insert(
		lines,
		string.format(
			"Tunnels   %s/%s ready%s",
			data.tunnels_ready or "?",
			data.tunnels_total or "?",
			#tunnels > 0 and (": " .. common.escape(table.concat(tunnels, ", "))) or ""
		)
	)
	-- versions: what apt offers, what's installed, what runs, what's out upstream
	local function base(v)
		return (v or ""):match("^(%d+%.%d+%.%d+)")
	end
	local installed, candidate, running = base(data.pkg_installed), base(data.pkg_candidate), base(data.version)
	if candidate and installed and candidate ~= installed then
		table.insert(lines, common.span("warn", "Update    " .. candidate .. " in apt: sudo apt upgrade"))
	end
	if installed and running and installed ~= running then
		table.insert(lines, common.span("warn", "Restart   to load " .. installed .. " (installed; " .. running .. " is running)"))
	end
	local upstream = base(data.update)
	if upstream and upstream ~= candidate and upstream ~= installed then
		table.insert(lines, common.span("dim", "Upstream  " .. upstream .. " released, not in the apt repo yet"))
	end
	table.insert(lines, common.span("dim", "\nClick: turn " .. (data.running == "yes" and "off" or "on") .. " · right click: more"))
	return table.concat(lines, "\n")
end

common.attach_popup(item, popup)
-- }}}

local refresh = common.watch("i2p-status.sh", 30, function(d)
	data = d
	render()
end)

-- {{{ Right-click menu
-- router runs i2prouter <action>, reports the result, and refreshes a few
-- times while the router comes up or goes down. Clicks while one runs are
-- ignored, so a double click can't start and stop it
local busy = false
local function router(action)
	if busy then
		return
	end
	busy = true
	awful.spawn.easy_async({ "i2prouter", action }, function(stdout, stderr)
		busy = false
		local out = (stdout .. stderr):gsub("%s+$", "")
		naughty.notify({ title = "I2P " .. action, text = out ~= "" and out or "done", timeout = 4 })
		for _, delay in ipairs({ 2, 10, 30 }) do
			gears.timer.start_new(delay, function()
				refresh()
				return false
			end)
		end
	end)
end

local function menu()
	local items = {
		{
			"Open router console",
			function()
				awful.spawn({ "xdg-open", CONSOLE })
			end,
		},
	}
	if data.running == "yes" then
		table.insert(items, {
			"Restart router",
			function()
				router("restart")
			end,
		})
		table.insert(items, {
			"Turn off",
			function()
				router("stop")
			end,
		})
	else
		table.insert(items, {
			"Turn on",
			function()
				router("start")
			end,
		})
	end
	common.menu(items)
end

-- click: on/off (instead of attach_popup's pin); right click: the menu
local function toggle()
	router(data.running == "yes" and "stop" or "start")
end
item:buttons(gears.table.join(awful.button({}, 1, toggle), awful.button({}, 3, menu)))
-- }}}

render()

i2p.widget = item

return i2p
