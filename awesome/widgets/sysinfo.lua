-- CPU, memory and network in the bar, through vicious (awesome-extra). Hover
-- for load, memory, swap and uptime; click to open btop
local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local vicious = require("vicious")
local dpi = require("beautiful.xresources").apply_dpi

local common = require("widgets.common")
local settings = require("config.settings")

local IFACE = settings.net_interface or "eno1"
local GLYPH = {
	cpu = utf8.char(0xf0ee0), -- nf-md-cpu_64_bit
	mem = utf8.char(0xf035b), -- nf-md-memory
	down = utf8.char(0xf01da), -- nf-md-download
	up = utf8.char(0xf0552), -- nf-md-upload
}

local sysinfo = {}

-- rate formats bytes per second in at most 5 characters: 0K, 1023K, 9.9M, 123M
local function rate(bytes)
	bytes = tonumber(bytes) or 0
	local mb = bytes / 1024 / 1024
	local text
	if mb >= 10 then
		text = string.format("%dM", math.floor(mb + 0.5))
	elseif bytes >= 1023.5 * 1024 then
		text = string.format("%.1fM", mb)
	else
		text = string.format("%dK", math.floor(bytes / 1024 + 0.5))
	end
	return common.num(text)
end

-- percent formats 0-100 with tabular digits
local function percent(value)
	return common.num(value .. "%")
end

-- level colours a percentage: warn from 75, bad from 90
local function level(pct)
	return pct >= 90 and "bad" or pct >= 75 and "warn" or nil
end

local function glyph(g)
	return wibox.widget({ markup = common.span("dim", g) .. " ", widget = wibox.widget.textbox })
end

-- each value sits in a box sized for its widest possible text, so the bar
-- never shifts as the numbers change
local cpu = common.fixed_text(percent(100))
local mem = common.fixed_text(percent(100))
local down = common.fixed_text(common.num("8888K"), common.num("88.8M"), common.num("888M"))
local up = common.fixed_text(common.num("8888K"), common.num("88.8M"), common.num("888M"))

vicious.cache(vicious.widgets.cpu)
vicious.cache(vicious.widgets.mem)
vicious.cache(vicious.widgets.net)

vicious.register(cpu, vicious.widgets.cpu, function(_, args)
	return common.span(level(args[1]), percent(args[1]))
end, 2)

vicious.register(mem, vicious.widgets.mem, function(_, args)
	return common.span(level(args[1]), percent(args[1]))
end, 5)

vicious.register(down, vicious.widgets.net, function(_, args)
	return rate(args["{" .. IFACE .. " down_b}"])
end, 2)

vicious.register(up, vicious.widgets.net, function(_, args)
	return rate(args["{" .. IFACE .. " up_b}"])
end, 2)

local function pair(g, value)
	return { glyph(g), value, layout = wibox.layout.fixed.horizontal }
end

local item = wibox.widget({
	{
		pair(GLYPH.cpu, cpu),
		pair(GLYPH.mem, mem),
		pair(GLYPH.down, down),
		pair(GLYPH.up, up),
		spacing = dpi(8),
		layout = wibox.layout.fixed.horizontal,
	},
	left = dpi(6),
	right = dpi(6),
	widget = wibox.container.margin,
})

local function read(path)
	local f = io.open(path)
	if not f then
		return ""
	end
	local s = f:read("*a")
	f:close()
	return s
end

awful.tooltip({
	objects = { item },
	mode = "outside",
	timer_function = function()
		local load1, load5, load15 = read("/proc/loadavg"):match("(%S+) (%S+) (%S+)")
		local m = vicious.widgets.mem()
		local up = tonumber(read("/proc/uptime"):match("^(%S+)")) or 0
		return string.format(
			"Load      %s  %s  %s\nMemory    %.1f / %.1f GB (%d%%)\nSwap      %.1f / %.1f GB\nUptime    %dd %dh\nNetwork   %s",
			load1 or "?", load5 or "?", load15 or "?",
			(m[2] or 0) / 1024, (m[3] or 0) / 1024, m[1] or 0,
			(m[6] or 0) / 1024, (m[7] or 0) / 1024,
			math.floor(up / 86400), math.floor(up % 86400 / 3600),
			IFACE
		)
	end,
})

item:buttons(gears.table.join(awful.button({}, 1, function()
	awful.spawn({ settings.terminal, "-e", "btop" })
end)))

sysinfo.widget = item

return sysinfo
