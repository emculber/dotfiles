-- Claude Code usage (the 5-hour and 7-day limits) in the bar: the
-- awesome-claude-usage widget (git submodule widgets/claude_usage, pinned to
-- v0.6.0), coloured from the theme, plus fixes for awesome 4.3, which it isn't
-- developed against:
--   * it sets clicks with `widget.buttons = {...}` (awesome-git only); 4.3
--     needs widget:buttons(...)
--   * its popup placement uses awesome-git arguments (see popup_placement)
local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")

local dpi = require("beautiful.xresources").apply_dpi

local settings = require("config.settings")

local claude_usage = require("widgets.claude_usage")
local common = require("widgets.common")

local p = beautiful.palette or {}

-- The bar text, "5h 50% · 7d 79%", as the plugin writes it, keeping the "⚑"
-- flag (a Claude Code session waiting for you). Without data, nil keeps the
-- plugin's own text ("…", "!auth", ...)
local ATTENTION = " " .. utf8.char(0x2691)
local function bar_text(st, fmt)
	if not fmt.has_data(st) then
		return nil
	end
	local parts = {}
	for _, w in ipairs({ { "5h", "five_hour" }, { "7d", "seven_day" } }) do
		local window = fmt.window(st, w[2])
		local pct = type(window) == "table" and type(window.percent) == "number"
				and (fmt.round(window.percent) .. "%")
			or "--"
		parts[#parts + 1] = w[1] .. " " .. pct
	end
	local text = table.concat(parts, " · ")
	if st.sessions and (st.sessions.attention or 0) > 0 then
		text = text .. ATTENTION
	end
	return text
end

-- The widget's width: icon + the plugin's spacing (dpi(5)) + the widest text
-- with room for the flag, measured in the bar font. Fixed, so the bar never
-- shifts as the text changes; the text sits on the left, so spare room ends
-- up next to the clock rather than as a gap after the volume
local function bar_width()
	local font_size = tonumber(tostring(beautiful.font):match("(%d+)%s*$")) or 10
	local icon = dpi(math.floor(font_size * 1.35 + 0.5))
	local probe = common.fixed_text(common.num(common.escape("5h 100% · 7d 100%" .. ATTENTION)))
	return icon + dpi(5) + probe.forced_width
end
local widget = claude_usage.new({
	style = "bare", -- icon + text in the theme's colours instead of the terracotta chip
	on_click = settings.terminal .. " -e claude",
	watch_cache = false, -- needs inotifywait and the statusLine helper, neither installed
	format = bar_text,
	forced_width = bar_width(),
	align = "left", -- any spare room (no flag) goes on the clock side
	-- its own placement passes preferred_anchors as a string, which 4.3 doesn't
	-- understand: the popup then stays at 0,0, which is off every monitor here.
	-- The same placement in 4.3's terms, opening under the bar
	popup_placement = function(d, geometry)
		if not geometry then
			return awful.placement.top_right(d, { honor_workarea = true, margins = dpi(4) })
		end
		return awful.placement.next_to(d, {
			preferred_positions = { "bottom", "top" },
			preferred_anchors = { "middle", "front", "back" },
			geometry = geometry,
		})
	end,
	colors = { warn = p.yellow, crit = p.red, error = p.fg_dim, icon = p.accent },
	popup_colors = {
		bg = p.bg,
		fg = p.fg,
		muted = p.fg_dim,
		border = p.surface,
		track = p.surface,
		accent = p.accent,
		warn = p.yellow,
		crit = p.red,
	},
})

-- 4.3 copies its widget methods into each widget, so the widget's
-- `buttons = {...}` replaced the buttons() method itself. Put the method back
-- and register the click handlers through it
local buttons = rawget(widget, "buttons")
if type(buttons) == "table" then
	widget.buttons = wibox.widget.base.widget.buttons
	widget:buttons(gears.table.join(table.unpack(buttons)))
end

-- tabular digits for the bar text, like the other widgets: the plugin escapes
-- its text and calls set_markup, so wrap that
local textbox = widget.textbox
local set_markup = textbox.set_markup
function textbox:set_markup(markup)
	return set_markup(self, common.num(markup))
end

-- Safety net: when Claude Code refreshes its login token, fetch again within a
-- minute, so a stalled poll or an "expired" state never sticks around while
-- the token is fine (v0.5.3 stopped polling for good after such an error)
local CREDENTIALS = os.getenv("HOME") .. "/.claude/.credentials.json"
local credentials_mtime
gears.timer({
	timeout = 60,
	autostart = true,
	callback = function()
		awful.spawn.easy_async({ "stat", "-c", "%Y", CREDENTIALS }, function(stdout)
			local mtime = tonumber(stdout)
			if mtime and credentials_mtime and mtime ~= credentials_mtime then
				widget.model.refresh({ force = true })
			end
			credentials_mtime = mtime or credentials_mtime
		end)
	end,
})

-- the same spacing as the other bar items
return {
	widget = wibox.container.margin(widget, dpi(6), dpi(6)),
	usage = widget,
}
