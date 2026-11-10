-- Wallpapers: rotated through backgrounds/ and backgrounds/Not-used/ every
-- day or hour (settings.wallpaper_rotation), or fixed per monitor
-- (settings.screens[...].wallpaper) when rotation is "off".
-- A monitor only gets pictures of its own shape: portrait monitors portrait
-- (or square) pictures, landscape monitors landscape (or square) ones. No
-- picture is on two monitors at once, and a monitor never gets the same one
-- twice in a row. The current picks live in ~/.cache/awesome/wallpapers, so
-- a Mod+Ctrl+r keeps them. Pictures are cropped to fill, never stretched
local gears = require("gears")
local beautiful = require("beautiful")
local GdkPixbuf = require("lgi").GdkPixbuf

local settings = require("config.settings")
local persist = require("modules.persist")

local wallpaper = {}

local DIRS = { settings.backgrounds, settings.backgrounds .. "Not-used/" }
local STATE_FILE = gears.filesystem.get_cache_dir() .. "wallpapers"

math.randomseed(os.time())

local function mode()
	return settings.wallpaper_rotation or "off"
end

-- period names the current day or hour; a new one means new wallpapers
local function period()
	if mode() == "hourly" then
		return os.date("%Y-%m-%d %H")
	end
	return os.date("%Y-%m-%d")
end

-- {{{ The pictures and their shapes
local function shape_of(w, h)
	local ratio = w / h
	if ratio < 0.8 then
		return "portrait"
	elseif ratio <= 1.25 then
		return "square"
	end
	return "landscape"
end

local pool, by_path

-- scan lists the pictures, reading only their headers for the size
function wallpaper.scan()
	pool, by_path = {}, {}
	for _, dir in ipairs(DIRS) do
		local ls = io.popen('ls -1 "' .. dir .. '" 2>/dev/null')
		for name in ls:lines() do
			local lower = name:lower()
			if lower:match("%.jpe?g$") or lower:match("%.png$") then
				local path = dir .. name
				local format, w, h = GdkPixbuf.Pixbuf.get_file_info(path)
				if format and w and h and w > 0 and h > 0 then
					local picture = { path = path, shape = shape_of(w, h) }
					table.insert(pool, picture)
					by_path[path] = picture
				end
			end
		end
		ls:close()
	end
end
-- }}}

-- {{{ Saved picks: output -> { file, period }
local state = {}

local function load_state()
	local f = io.open(STATE_FILE)
	if not f then
		return
	end
	for line in f:lines() do
		local output, file, when = line:match("^([^\t]+)\t([^\t]+)\t([^\t]*)$")
		if output then
			state[output] = { file = file, period = when }
		end
	end
	f:close()
end

local function save_state()
	local f = io.open(STATE_FILE, "w")
	if not f then
		return
	end
	for output, pick in pairs(state) do
		f:write(output, "\t", pick.file, "\t", pick.period or "", "\n")
	end
	f:close()
end
-- }}}

local function is_portrait(s)
	return s.geometry.height > s.geometry.width
end

-- fits says whether picture suits screen s's shape
local function fits(picture, s)
	if not picture then
		return false
	end
	if picture.shape == "square" then
		return true
	end
	return (picture.shape == "portrait") == is_portrait(s)
end

-- pick chooses a picture for s, avoiding taken ones and previous (in that
-- order of importance after the shape), but never leaving s without one
local function pick(s, taken, previous)
	local tiers = {
		function(p)
			return fits(p, s) and not taken[p.path] and p.path ~= previous
		end,
		function(p)
			return fits(p, s) and not taken[p.path]
		end,
		function(p)
			return fits(p, s)
		end,
		function()
			return true
		end,
	}
	for _, ok in ipairs(tiers) do
		local choices = {}
		for _, p in ipairs(pool) do
			if ok(p) then
				table.insert(choices, p)
			end
		end
		if #choices > 0 then
			return choices[math.random(#choices)].path
		end
	end
end

local function draw(s, path)
	gears.wallpaper.maximized(path, s, false)
end

-- fixed shows settings.screens[...].wallpaper, the theme's, or a plain colour
local function fixed(s)
	local cfg = settings.screens[persist.output(s)] or settings.screen_default or {}
	local path = cfg.wallpaper and settings.backgrounds .. cfg.wallpaper or beautiful.wallpaper
	if path then
		draw(s, path)
	else
		gears.wallpaper.tiled(gears.surface.load_from_shape(1, 1, gears.shape.rectangle, beautiful.bg_normal), s)
	end
end

-- taken_by_others is the set of pictures on the other connected monitors
local function taken_by_others(s)
	local taken = {}
	for other in screen do
		local saved = other ~= s and state[persist.output(other)]
		if saved then
			taken[saved.file] = true
		end
	end
	return taken
end

-- apply sets s's wallpaper: its saved pick while that's still current and
-- fits, else a new one
function wallpaper.apply(s)
	if mode() == "off" or #pool == 0 then
		return fixed(s)
	end
	local output = persist.output(s)
	local saved = state[output]
	if saved and saved.period == period() and fits(by_path[saved.file], s) then
		return draw(s, saved.file)
	end
	local path = pick(s, taken_by_others(s), saved and saved.file)
	state[output] = { file = path, period = period() }
	save_state()
	draw(s, path)
end

-- next gives every monitor a new picture (the menu entry and Mod+Shift+w)
function wallpaper.next()
	if #pool == 0 then
		return
	end
	local taken = {}
	for s in screen do
		local output = persist.output(s)
		local path = pick(s, taken, state[output] and state[output].file)
		taken[path] = true
		state[output] = { file = path, period = period() }
		draw(s, path)
	end
	save_state()
end

-- current returns output -> picture path, for checking
function wallpaper.current()
	local picks = {}
	for output, saved in pairs(state) do
		picks[output] = saved.file
	end
	return picks
end

wallpaper.scan()
load_state()

-- a new day (or hour) changes them on the next check
gears.timer({
	timeout = 600,
	autostart = true,
	callback = function()
		if mode() == "off" then
			return
		end
		for s in screen do
			local saved = state[persist.output(s)]
			if not saved or saved.period ~= period() then
				return wallpaper.next()
			end
		end
	end,
})

return wallpaper
