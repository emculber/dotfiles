-- Screen colour temperature in the bar (modules/idle_dim.lua), e.g. 3000K.
-- Scroll for ±100 K, click to go back to the schedule; dimmed while the
-- screens are idle-dimmed. Same as Mod+F11 / Mod+F12 / Mod+F10
local gears = require("gears")
local awful = require("awful")

local common = require("widgets.common")
local idle_dim = require("modules.idle_dim")

local GLYPH = utf8.char(0xf0594) -- nf-md-weather_night
local STEP = 100

local nightlight = {}

local item = common.bar_item(common.item_markup(GLYPH, "10000K"))
local tooltip = awful.tooltip({ objects = { item }, mode = "outside" })

local function render()
	local t, scheduled, offset = idle_dim.temperature()
	item:update(GLYPH, common.pad(t .. "K", 6), idle_dim.is_dimmed() and "dim" or nil)
	tooltip.text = string.format(
		"Screen temperature %d K\nScheduled %d K%s\nScroll ±%d K · click: back to schedule",
		t,
		scheduled,
		offset ~= 0 and string.format(" (%+d K by hand)", offset) or "",
		STEP
	)
end

item:buttons(gears.table.join(
	awful.button({}, 1, function()
		idle_dim.reset_temp(true)
		render()
	end),
	awful.button({}, 4, function()
		idle_dim.shift_temp(STEP, true)
		render()
	end),
	awful.button({}, 5, function()
		idle_dim.shift_temp(-STEP, true)
		render()
	end)
))

-- the temperature changes with the schedule, the keys and scrolling here; the
-- brightness changes with idle dimming
awesome.connect_signal("idle_dim::temperature", render)
awesome.connect_signal("idle_dim::dimmed", render)
awesome.connect_signal("idle_dim::undimmed", render)
render()

nightlight.widget = item

return nightlight
