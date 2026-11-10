-- Volume in the bar (PipeWire, via wpctl): glyph + percent of the default
-- output. Scroll changes it, left click mutes, middle click opens pavucontrol,
-- right click opens a panel with a slider, the outputs to switch between, a
-- mixer with each playing app's volume and output, and mic mute.
-- Volume can be boosted past 100% up to settings.volume.max, like pavucontrol;
-- the glyph turns yellow while it is.
-- volume.up/down/toggle_mute/toggle_mic are also the media keys
-- (config/keys.lua), which show a small on-screen notification
local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local naughty = require("naughty")
local dpi = require("beautiful.xresources").apply_dpi

local common = require("widgets.common")
local settings = require("config.settings")

local SINK = "@DEFAULT_AUDIO_SINK@"
local SOURCE = "@DEFAULT_AUDIO_SOURCE@"
local opts = settings.volume or {}
local MAX = opts.max or 150 -- percent
local LIMIT = string.format("%.2f", MAX / 100) -- for wpctl set-volume -l
local STEP = (opts.step or 5) .. "%"
local NAMES = opts.names or {}
local STREAMS = gears.filesystem.get_configuration_dir() .. "scripts/audio-streams.sh"

local GLYPH = {
	high = utf8.char(0xf057e), -- nf-md-volume_high
	mid = utf8.char(0xf0580), -- nf-md-volume_medium
	low = utf8.char(0xf057f), -- nf-md-volume_low
	muted = utf8.char(0xf075f), -- nf-md-volume_off
	mic = utf8.char(0xf036c), -- nf-md-microphone
	mic_off = utf8.char(0xf036d), -- nf-md-microphone_off
}

local volume = {}

local state = {
	volume = 0, -- 0..MAX/100
	muted = false,
	mic_muted = false,
	sinks = {}, -- { id, serial, node, name, default } from scripts/audio-streams.sh
	streams = {}, -- { id, app, media, volume, muted, target, linked }
}

-- fixed to its widest look, so a changing glyph or percentage never shifts the bar
local item = common.bar_item(
	common.item_markup(GLYPH.high, "100%"),
	common.item_markup(GLYPH.mid, "100%"),
	common.item_markup(GLYPH.low, "100%"),
	common.item_markup(GLYPH.muted, "100%")
)
local tooltip = awful.tooltip({ objects = { item }, mode = "outside" })
local panel -- the right-click popup, built on demand

local function pct(v)
	return math.floor(v * 100 + 0.5)
end

local function percent()
	return pct(state.volume)
end

local function glyph()
	if state.muted then
		return GLYPH.muted
	elseif state.volume >= 0.66 then
		return GLYPH.high
	elseif state.volume >= 0.33 then
		return GLYPH.mid
	end
	return GLYPH.low
end

-- short_name gives an output its settings.volume.names nickname, if any
local function short_name(name)
	for part, nick in pairs(NAMES) do
		if name:find(part, 1, true) then
			return nick
		end
	end
	return name
end

local function default_sink()
	for _, sink in ipairs(state.sinks) do
		if sink.default then
			return sink
		end
	end
end

local function default_sink_name()
	local sink = default_sink()
	return sink and short_name(sink.name) or "Default output"
end

local function render()
	local level = state.muted and "dim" or (percent() > 100 and "warn" or nil)
	item:update(glyph(), common.pad(percent() .. "%", 4), level)
	tooltip.text = string.format(
		"%s: %d%%%s%s",
		default_sink_name(),
		percent(),
		percent() > 100 and " (boosted)" or "",
		state.muted and " (muted)" or ""
	)
	if panel and panel.visible then
		panel:sync()
	end
end

-- parse_volume reads "Volume: 0.40" or "Volume: 0.40 [MUTED]"
local function parse_volume(stdout)
	return tonumber(stdout:match("Volume: ([%d.]+)")), stdout:find("MUTED") ~= nil
end

local function split_tabs(line)
	local fields = {}
	for field in (line .. "\t"):gmatch("([^\t]*)\t") do
		table.insert(fields, field)
	end
	return fields
end

-- parse_streams reads scripts/audio-streams.sh: the outputs and the apps playing
local function parse_streams(stdout)
	local default, sinks, streams = nil, {}, {}
	for line in stdout:gmatch("[^\n]+") do
		local f = split_tabs(line)
		if f[1] == "default" then
			default = f[2]
		elseif f[1] == "sink" then
			table.insert(sinks, { id = f[2], serial = f[3], node = f[4], name = f[5] })
		elseif f[1] == "stream" then
			local linear = tonumber(f[5]) or 1
			table.insert(streams, {
				id = f[2],
				app = f[3],
				media = f[4],
				volume = linear ^ (1 / 3), -- the cubic scale wpctl and pavucontrol show
				muted = f[6] == "true",
				target = f[7], -- a sink serial (or name) when moved off the default
				linked = f[8]:match("^(%d+)"), -- the sink it plays on right now
			})
		end
	end
	for _, sink in ipairs(sinks) do
		sink.default = sink.node == default
	end
	-- the order wpctl status uses: by id
	table.sort(sinks, function(a, b)
		return tonumber(a.id) < tonumber(b.id)
	end)
	table.sort(streams, function(a, b)
		return tonumber(a.id) < tonumber(b.id)
	end)
	return sinks, streams
end

-- refresh reads the volumes (and, with full = true, the outputs and the apps
-- playing)
function volume.refresh(full, callback)
	awful.spawn.easy_async({ "wpctl", "get-volume", SINK }, function(out)
		local v, muted = parse_volume(out)
		if v then
			state.volume, state.muted = v, muted
		end
		awful.spawn.easy_async({ "wpctl", "get-volume", SOURCE }, function(out2)
			local _, mic_muted = parse_volume(out2)
			state.mic_muted = mic_muted
			if not full then
				render()
				return callback and callback()
			end
			awful.spawn.easy_async({ STREAMS }, function(stdout)
				-- an empty answer means pw-dump failed this once: keep the old lists
				if stdout:find("sink\t") then
					state.sinks, state.streams = parse_streams(stdout)
				end
				render()
				return callback and callback()
			end)
		end)
	end)
end

local osd
local function show_osd()
	local p = percent()
	local bars = math.floor(math.min(p, 100) / 10)
	local boost = p > 100 and (" " .. string.rep("▲", math.floor((p - 100) / 10 + 0.5))) or ""
	osd = naughty.notify({
		title = (state.muted and "Volume (muted)") or (p > 100 and "Volume (boosted)") or "Volume",
		text = string.rep("■", bars) .. string.rep("□", 10 - bars) .. boost .. "  " .. p .. "%",
		timeout = 1.5,
		replaces_id = osd and osd.id,
	})
end

-- run runs a command, refreshes, then calls after (if given). With full =
-- true the refresh also re-reads the outputs and apps
local function run(cmd, after, full)
	awful.spawn.easy_async(cmd, function()
		volume.refresh(full, after)
	end)
end

local function wpctl(args, after, full)
	local cmd = { "wpctl" }
	for _, a in ipairs(args) do
		table.insert(cmd, a)
	end
	run(cmd, after, full)
end

-- show = true (media keys) shows the on-screen notification afterwards
function volume.up(show)
	wpctl({ "set-volume", "-l", LIMIT, SINK, STEP .. "+" }, show and show_osd)
end

function volume.down(show)
	wpctl({ "set-volume", SINK, STEP .. "-" }, show and show_osd)
end

function volume.set(percent_value)
	wpctl({ "set-volume", "-l", LIMIT, SINK, percent_value .. "%" })
end

function volume.toggle_mute(show)
	wpctl({ "set-mute", SINK, "toggle" }, show and show_osd)
end

local mic_osd
function volume.toggle_mic(show)
	wpctl({ "set-mute", SOURCE, "toggle" }, show and function()
		mic_osd = naughty.notify({
			title = "Microphone",
			text = state.mic_muted and "muted" or "on",
			timeout = 1.5,
			replaces_id = mic_osd and mic_osd.id,
		})
	end)
end

function volume.set_default(id)
	wpctl({ "set-default", id }, nil, true)
end

-- {{{ Apps: each playing stream's volume, mute and output
function volume.set_stream(id, percent_value)
	wpctl({ "set-volume", "-l", LIMIT, id, percent_value .. "%" }, nil, true)
end

function volume.toggle_stream_mute(id)
	wpctl({ "set-mute", id, "toggle" }, nil, true)
end

-- move_stream sends an app to an output (by its serial); nil sends it back to
-- the default output. WirePlumber remembers the choice for that app
function volume.move_stream(id, serial)
	if serial then
		run({ "pw-metadata", id, "target.object", serial }, nil, true)
	else
		run({ "pw-metadata", "-d", id, "target.object" }, nil, true)
	end
end

-- stream_sink is the output a stream plays on: where it was sent, else where
-- it is linked right now
local function stream_sink(stream)
	for _, sink in ipairs(state.sinks) do
		if stream.target ~= "" and (sink.serial == stream.target or sink.node == stream.target) then
			return sink
		end
	end
	for _, sink in ipairs(state.sinks) do
		if sink.id == stream.linked then
			return sink
		end
	end
end

local function truncate(text, n)
	if utf8.len(text) <= n then
		return text
	end
	return text:sub(1, utf8.offset(text, n) - 1) .. "…"
end
-- }}}

-- {{{ Right-click panel

-- make_slider returns a 0..MAX slider calling on_change(percent) with the last
-- value of a drag, and a label showing its percent (yellow above 100).
-- slider:set(percent) moves it without calling on_change
local function make_slider(width, on_change)
	local slider = wibox.widget({
		maximum = MAX,
		forced_width = width,
		forced_height = dpi(16),
		bar_height = dpi(3),
		bar_color = beautiful.palette and beautiful.palette.surface or beautiful.bg_focus,
		handle_shape = gears.shape.circle,
		handle_width = dpi(12),
		widget = wibox.widget.slider,
	})
	local label = wibox.widget({
		align = "right",
		forced_width = dpi(44),
		widget = wibox.widget.textbox,
	})
	local syncing = false
	local pending

	local function paint()
		local boosted = slider.value > 100
		local color = boosted and common.color("warn") or common.color("accent")
		slider.bar_active_color = color
		slider.handle_color = color
		label.markup = common.span(boosted and "warn" or nil, common.num(slider.value .. "%"))
	end

	slider:connect_signal("property::value", function()
		paint()
		if syncing then
			return
		end
		slider.touched = os.time()
		-- the slider fires on every pixel of a drag; send the last value
		pending = slider.value
		gears.timer.delayed_call(function()
			if pending then
				on_change(pending)
				pending = nil
			end
		end)
	end)

	function slider:set(value)
		syncing = true
		self.value = math.min(value, MAX)
		syncing = false
		paint()
	end

	paint()
	local row = wibox.widget({
		slider,
		{ label, left = dpi(6), widget = wibox.container.margin },
		layout = wibox.layout.fixed.horizontal,
	})
	return slider, row
end

local function build_panel()
	local slider, slider_row = make_slider(dpi(220), volume.set)

	local list = wibox.layout.fixed.vertical()
	local apps = wibox.layout.fixed.vertical()
	local mic = wibox.layout.fixed.vertical()

	local expanded -- the stream id whose output choices are showing
	local app_sliders = {}
	local p

	-- app_block is one app: name (click = mute), its output (click = choose
	-- another), and a volume slider
	local function app_block(stream)
		local sink = stream_sink(stream)
		local where = sink and short_name(sink.name) or "?"
		if stream.target == "" then
			where = where .. common.span("dim", " (default)")
		end
		local name = common.escape(truncate(stream.app, 22))
		local name_markup = stream.muted and common.span("dim", GLYPH.muted .. " " .. name) or name
		local open = expanded == stream.id

		local s, s_row = make_slider(dpi(180), function(value)
			volume.set_stream(stream.id, value)
		end)
		s:set(pct(stream.volume))
		app_sliders[stream.id] = s

		local block = wibox.layout.fixed.vertical()
		block:add(wibox.widget({
			common.row(name_markup, function()
				volume.toggle_stream_mute(stream.id)
			end),
			nil,
			common.row(common.span("accent", where .. (open and " ▴" or " ▾")), function()
				expanded = (not open) and stream.id or nil
				gears.timer.delayed_call(function()
					p:sync(true)
				end)
			end),
			layout = wibox.layout.align.horizontal,
		}))
		block:add(wibox.widget({ s_row, left = dpi(6), bottom = dpi(4), widget = wibox.container.margin }))

		if open then
			local choices = wibox.layout.fixed.vertical()
			local default = default_sink()
			choices:add(common.row(
				(stream.target == "" and common.span("accent", "● ") or "○ ")
					.. "Default"
					.. common.span("dim", " (follows " .. common.escape(default and short_name(default.name) or "main output") .. ")"),
				function()
					expanded = nil
					volume.move_stream(stream.id, nil)
				end
			))
			for _, choice in ipairs(state.sinks) do
				local chosen = stream.target ~= "" and sink == choice
				choices:add(common.row(
					(chosen and common.span("accent", "● ") or "○ ") .. common.escape(short_name(choice.name)),
					function()
						expanded = nil
						volume.move_stream(stream.id, choice.serial)
					end
				))
			end
			block:add(wibox.widget({ choices, left = dpi(16), bottom = dpi(4), widget = wibox.container.margin }))
		end
		return block
	end

	p = common.panel({
		common.heading("Volume", true),
		{ slider_row, top = dpi(4), bottom = dpi(4), widget = wibox.container.margin },
		common.heading("Output"),
		list,
		common.heading("Apps"),
		apps,
		common.heading("Microphone"),
		mic,
		{
			common.row(common.span("dim", "Open pavucontrol…"), function()
				awful.spawn("pavucontrol")
			end),
			top = dpi(8),
			widget = wibox.container.margin,
		},
		layout = wibox.layout.fixed.vertical,
	})

	-- an app slider moved in the last 2 s is being dragged: leave the list
	-- alone until it's let go, so a refresh doesn't pull it from the mouse
	local function dragging()
		for _, s in pairs(app_sliders) do
			if s.touched and os.time() - s.touched < 2 then
				return true
			end
		end
		return false
	end

	-- sync redraws the panel from state (force = redraw the apps even mid-drag)
	function p:sync(force)
		slider:set(percent())

		list:reset()
		for _, sink in ipairs(state.sinks) do
			local mark = sink.default and common.span("accent", "● ") or "○ "
			local name = short_name(sink.name)
			local extra = name ~= sink.name and common.span("dim", "  " .. common.escape(truncate(sink.name, 28))) or ""
			list:add(common.row(mark .. common.escape(name) .. extra, function()
				volume.set_default(sink.id)
			end))
		end

		if force or not dragging() then
			apps:reset()
			app_sliders = {}
			local seen = false
			for _, stream in ipairs(state.streams) do
				if stream.id == expanded then
					seen = true
				end
				apps:add(app_block(stream))
			end
			if not seen then
				expanded = nil
			end
			if #state.streams == 0 then
				apps:add(common.row(common.span("dim", "Nothing playing")))
			end
		end

		mic:reset()
		local label = state.mic_muted and (GLYPH.mic_off .. " muted (click to unmute)")
			or (GLYPH.mic .. " on (click to mute)")
		mic:add(common.row(common.span(state.mic_muted and "warn" or nil, label), function()
			volume.toggle_mic(false)
		end))
	end

	return p
end

local function toggle_panel()
	panel = panel or build_panel()
	if panel.visible then
		panel.visible = false
		return
	end
	-- where the click was, before the refresh below gives the mouse time to move
	local geometry = mouse.current_widget_geometry
	volume.refresh(true, function()
		panel:sync(true)
		panel:show_at(geometry)
	end)
end
-- }}}

item:buttons(gears.table.join(
	awful.button({}, 1, function()
		volume.toggle_mute(false)
	end),
	awful.button({}, 2, function()
		awful.spawn("pavucontrol")
	end),
	awful.button({}, 3, toggle_panel),
	awful.button({}, 4, function()
		volume.up(false)
	end),
	awful.button({}, 5, function()
		volume.down(false)
	end)
))

-- volume every 2 s (catches changes made elsewhere, e.g. pavucontrol), plus
-- the outputs and apps while the panel is open; the outputs every 30 s
-- otherwise, for the tooltip's device name
volume.refresh(true)
gears.timer({
	timeout = 2,
	autostart = true,
	callback = function()
		volume.refresh(panel ~= nil and panel.visible)
	end,
})
gears.timer({ timeout = 30, autostart = true, callback = function() volume.refresh(true) end })

volume.widget = item
volume.toggle_panel = toggle_panel -- also for awesome-client

return volume
