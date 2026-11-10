-- I2P router in the bar: the I2P logo (widgets/icons/i2p.png, cut from the
-- router console's logo) tinted by status: green when the network is OK,
-- yellow when Firewalled or still starting, dim when the router is stopped.
-- Hover for version, uptime, bandwidth and tunnels (click pins it); right
-- click to open the console or start / stop / restart the router.
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
		return "<b>I2P</b>  stopped\n\nRight click to start it"
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
	if data.update and data.update ~= "" then
		table.insert(lines, common.span("warn", "Update    " .. common.escape(data.update) .. " available (apt)"))
	end
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
-- times while the router comes up or goes down
local function router(action)
	awful.spawn.easy_async({ "i2prouter", action }, function(stdout, stderr)
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
			"Stop router",
			function()
				router("stop")
			end,
		})
	else
		table.insert(items, {
			"Start router",
			function()
				router("start")
			end,
		})
	end
	common.menu(items)
end

item:buttons(gears.table.join(item:buttons(), awful.button({}, 3, menu)))
-- }}}

render()

i2p.widget = item

return i2p
