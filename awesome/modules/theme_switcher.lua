-- Loads the theme and switches between them. A theme is either a full theme
-- file in themes/ (e.g. original.lua) or a palette in themes/palettes/ that
-- themes/base.lua turns into one. The name comes from, in order:
--   AWESOME_THEME             set by scripts/preview-themes.sh
--   ~/.cache/awesome/theme    written by the Themes menu
--   settings.theme
local gears = require("gears")
local beautiful = require("beautiful")
local naughty = require("naughty")

local settings = require("config.settings")

local switcher = {}

local dir = gears.filesystem.get_configuration_dir() .. "themes/"
local choice_file = gears.filesystem.get_cache_dir() .. "theme"

local function lua_files(path)
	local names = {}
	local ls = io.popen('ls "' .. path .. '" 2>/dev/null')
	for file in ls:lines() do
		local name = file:match("^(.+)%.lua$")
		if name then
			names[#names + 1] = name
		end
	end
	ls:close()
	return names
end

-- list returns every theme name, sorted
function switcher.list()
	local names = {}
	for _, name in ipairs(lua_files(dir)) do
		if name ~= "base" then
			names[#names + 1] = name
		end
	end
	for _, name in ipairs(lua_files(dir .. "palettes/")) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

-- resolve returns what beautiful.init takes for theme name: a file path or a
-- theme table, or nil when there is no such theme
local function resolve(name)
	if name ~= "base" and gears.filesystem.file_readable(dir .. name .. ".lua") then
		return dir .. name .. ".lua"
	end

	local palette = dir .. "palettes/" .. name .. ".lua"
	if gears.filesystem.file_readable(palette) then
		return require("themes.base")(dofile(palette))
	end
end

local function saved_choice()
	local f = io.open(choice_file)
	if not f then
		return nil
	end
	local name = f:read("l")
	f:close()
	return name
end

-- init loads the chosen theme, falling back to settings.theme and then to the
-- untouched original if a theme is missing or fails
function switcher.init()
	-- any source can be nil, and a nil would end an ipairs loop early, so only
	-- the ones that are set go in, in priority order
	local candidates = {}
	local function add(name)
		if name then
			candidates[#candidates + 1] = name
		end
	end
	add(os.getenv("AWESOME_THEME"))
	add(saved_choice())
	add(settings.theme)
	add("original")

	for _, name in ipairs(candidates) do
		local ok, theme = pcall(resolve, name)
		if ok and theme and beautiful.init(theme) then
			switcher.current = name
			return
		end
		if not ok then
			naughty.notify({ preset = naughty.config.presets.critical, title = "Theme " .. name .. " failed", text = theme })
		end
	end
end

-- set saves name as the theme and restarts awesome to apply it
function switcher.set(name)
	local f = io.open(choice_file, "w")
	f:write(name, "\n")
	f:close()
	awesome.restart()
end

-- menu returns the items for an awful.menu submenu, the current theme marked
function switcher.menu()
	local items = {}
	for _, name in ipairs(switcher.list()) do
		local label = (name == switcher.current and "● " or "   ") .. name
		items[#items + 1] = {
			label,
			function()
				switcher.set(name)
			end,
		}
	end
	return items
end

return switcher
