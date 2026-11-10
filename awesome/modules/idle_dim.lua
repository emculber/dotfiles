-- Screen colour temperature through the day, and dimming when idle, both done
-- with xsct (gamma). This replaced the xsct lines in crontab: with one owner
-- of the gamma, the schedule and the dim can't overwrite each other.
-- Settings: settings.temperature, settings.brightness, settings.idle_timeout
local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")

local settings = require("config.settings")

local idle_dim = {
	timeout = settings.idle_timeout, -- seconds; change at runtime to test
	debug = false, -- log every xsct call to stderr
}

local schedule = gears.table.clone(settings.temperature)
table.sort(schedule, function(a, b)
	return a[1] < b[1]
end)
local bright = settings.brightness

local state = {
	slot = nil, -- index into schedule
	offset = 0, -- manual shift from Mod+F11/F12, kelvin
	dimmed = false,
	applied = nil, -- last "temp brightness" sent to xsct
	last_idle = 0, -- ms, previous xprintidle reading
	polling = false,
	playing_until = 0, -- os.time() before which media counts as playing
}

local warned = {}
local function warn_once(key, text)
	if not warned[key] then
		warned[key] = true
		naughty.notify({ preset = naughty.config.presets.critical, title = "idle_dim", text = text })
	end
end

local function hour()
	return tonumber(os.date("%H"))
end

local function current_slot()
	-- before the first entry, the last one (from the day before) still applies
	local slot = #schedule
	for i, entry in ipairs(schedule) do
		if hour() >= entry[1] then
			slot = i
		end
	end
	return slot
end

local function temperature()
	return math.max(1000, math.min(10000, schedule[state.slot][2] + state.offset))
end

local function brightness()
	if state.dimmed then
		return bright.idle
	end
	local h = hour()
	if h >= bright.day_from and h < bright.night_from then
		return bright.day
	end
	return bright.night
end

-- xsct runs xsct with args, then calls after (if given)
local function xsct(args, after)
	if idle_dim.debug then
		io.stderr:write("idle_dim: xsct " .. table.concat(args, " ") .. "\n")
	end
	local cmd = { "xsct" }
	for _, a in ipairs(args) do
		table.insert(cmd, a)
	end
	local pid = awful.spawn.easy_async(cmd, function(_, stderr, _, code)
		if code ~= 0 then
			warn_once("xsct", "xsct failed: " .. stderr)
		end
		if after then
			after()
		end
	end)
	if type(pid) == "string" then
		warn_once("xsct", "can't run xsct: " .. pid)
	end
end

-- with_crtc finds the CRTC number xsct -c needs for the monitor called output
-- (e.g. "HDMI-0") in `xrandr --verbose`, and calls callback with it (or nil)
local function with_crtc(output, callback)
	awful.spawn.easy_async({ "xrandr", "--verbose" }, function(stdout)
		local current
		for line in stdout:gmatch("[^\n]+") do
			local name = line:match("^(%S+) connected")
			if name then
				current = name
			end
			local crtc = line:match("^%s+CRTC:%s+(%d+)")
			if crtc and current then
				if current == output then
					return callback(crtc)
				end
				current = nil
			end
		end
		callback(nil)
	end)
end

-- number formats a brightness for xsct (%.2f can print a decimal comma under
-- some locales; xsct wants a point)
local function number(value)
	return (string.format("%.2f", value):gsub(",", "."))
end

-- apply sends the current temperature and brightness to xsct, if they changed
-- or force is set. While dimmed, the idle clock's monitor (settings.idle_clock)
-- gets its own, higher brightness, so the clock on it stays readable
local function apply(force)
	local b = number(brightness())
	local t = tostring(temperature())
	if t ~= state.announced then
		-- for widgets/nightlight.lua
		state.announced = t
		awesome.emit_signal("idle_dim::temperature", temperature())
	end
	local value = t .. " " .. b
	if value == state.applied and not force then
		return
	end
	state.applied = value

	local clock = settings.idle_clock
	local after
	if state.dimmed and clock and clock.output then
		after = function()
			with_crtc(clock.output, function(crtc)
				if crtc and state.dimmed then
					xsct({ "-c", crtc, t, number(clock.brightness or bright.idle) })
				end
			end)
		end
	end
	xsct({ t, b }, after)
end

-- set_dimmed dims or undims, and tells the rest of the config through the
-- signals idle_dim::dimmed / idle_dim::undimmed on awesome (modules/idle_clock.lua)
local function set_dimmed(dimmed)
	if state.dimmed ~= dimmed then
		state.dimmed = dimmed
		apply()
		awesome.emit_signal(dimmed and "idle_dim::dimmed" or "idle_dim::undimmed")
	end
end

-- dim_if_nothing_plays dims unless an MPRIS player (browser video, Spotify...)
-- is playing; after a Playing answer it waits 30 s before asking again
local function dim_if_nothing_plays()
	if os.time() < state.playing_until then
		return
	end
	state.playing_until = os.time() + 30 -- also stops repeat checks while this one runs

	awful.spawn.easy_async({ "playerctl", "-a", "status" }, function(stdout)
		if stdout:find("Playing") then
			return
		end
		state.playing_until = 0
		if not state.dimmed then
			set_dimmed(true)
		end
	end)
end

local function poll_idle(timer)
	if state.polling then
		return
	end
	state.polling = true

	local pid = awful.spawn.easy_async({ "xprintidle" }, function(stdout)
		state.polling = false
		local ms = tonumber(stdout)
		if not ms then
			warn_once("xprintidle", "xprintidle gave no idle time, idle dimming is off")
			timer:stop()
			return
		end

		-- the idle counter only goes down when there was input
		local active = ms < state.last_idle
		state.last_idle = ms

		if state.dimmed and active then
			set_dimmed(false)
		elseif not state.dimmed and ms >= idle_dim.timeout * 1000 then
			dim_if_nothing_plays()
		end
	end)

	if type(pid) == "string" then
		state.polling = false
		warn_once("xprintidle", "can't run xprintidle (sudo apt install xprintidle), idle dimming is off: " .. pid)
		timer:stop()
	end
end

local function on_schedule_tick()
	local slot = current_slot()
	if slot ~= state.slot then
		state.slot = slot
		state.offset = 0
	end
	-- forced, so gamma reset by a wake from suspend is fixed within a minute
	apply(true)
end

-- shift_temp moves the temperature by delta kelvin until the next schedule
-- slot; quiet = true skips the on-screen message (the bar widget shows it)
function idle_dim.shift_temp(delta, quiet)
	state.offset = state.offset + delta
	apply()
	if quiet then
		return
	end
	idle_dim.notification = naughty.notify({
		title = "Temperature",
		text = temperature() .. " K",
		timeout = 1.5,
		replaces_id = idle_dim.notification and idle_dim.notification.id,
	})
end

-- reset_temp goes back to the scheduled temperature
function idle_dim.reset_temp(quiet)
	idle_dim.shift_temp(-state.offset, quiet)
end

-- temperature returns the current temperature (kelvin), the scheduled one and
-- the manual offset
function idle_dim.temperature()
	return temperature(), schedule[state.slot][2], state.offset
end

-- is_dimmed says whether the screens are idle-dimmed right now
function idle_dim.is_dimmed()
	return state.dimmed
end

-- dim dims right away, as if idle; the next input undims as usual
function idle_dim.dim()
	set_dimmed(true)
end

-- status returns the state, for awesome-client checks
function idle_dim.status()
	return string.format(
		"slot %d (%02d:00) temp %d K, brightness %s, dimmed %s, offset %d, timeout %ds",
		state.slot,
		schedule[state.slot][1],
		temperature(),
		brightness(),
		tostring(state.dimmed),
		state.offset,
		idle_dim.timeout
	)
end

on_schedule_tick()
gears.timer({ timeout = 60, autostart = true, callback = on_schedule_tick })

local idle_timer
idle_timer = gears.timer({
	timeout = 1,
	autostart = true,
	callback = function()
		poll_idle(idle_timer)
	end,
})

return idle_dim
