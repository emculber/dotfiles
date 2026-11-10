-- Keeps each window's monitor and tags, and each tag's layout and name, across
-- awesome restarts. Awesome 4.3 puts windows back by a tag number counted
-- across all screens, and the screens are numbered differently from one
-- restart to the next, so windows land on the wrong monitor. This stores
-- output names (HDMI-0, DP-4, ...) and tag positions (1-9) instead: on each
-- window, and on the root window for the tags. Positions rather than names, so
-- renaming a tag never loses its windows. X properties live as long as the X
-- session, so a fresh login starts from the defaults
local gears = require("gears")
local awful = require("awful")

local persist = {}

-- "<output>\t<position>\t<position>..." on each client
local CLIENT_PROP = "awesome.persist.place"
-- one "<output>\t<position>\t<layout>\t<selected>\t<name>\t<default name>"
-- line per tag, on the root window
local TAGS_PROP = "awesome.persist.tags"

awesome.register_xproperty(CLIENT_PROP, "string")
awesome.register_xproperty(TAGS_PROP, "string")

local function split(s)
	local fields = {}
	for field in s:gmatch("[^\t]+") do
		fields[#fields + 1] = field
	end
	return fields
end

-- position reads a saved tag position. Older saves have tag names there
-- ("3", or "3:web"), which start with the position too
local function position(field)
	return tonumber((field or ""):match("^(%d+)"))
end

-- output returns the xrandr output name of screen s, e.g. "HDMI-0", or
-- "screen<index>" when X reports none (Xephyr)
function persist.output(s)
	for name in pairs(s.outputs) do
		return name
	end
	return "screen" .. s.index
end

local function screen_by_output(name)
	for s in screen do
		if persist.output(s) == name then
			return s
		end
	end
end

local function layout_by_name(name)
	for _, l in ipairs(awful.layout.layouts) do
		if l.name == name then
			return l
		end
	end
end

local function save_client(c)
	if not c.valid then
		return
	end

	local tags = c:tags()
	if #tags == 0 then
		return
	end

	local fields = { persist.output(tags[1].screen) }
	for _, t in ipairs(tags) do
		fields[#fields + 1] = tostring(t.index)
	end
	c:set_xproperty(CLIENT_PROP, table.concat(fields, "\t"))
end

local function save_tags()
	local lines = {}
	for s in screen do
		local output = persist.output(s)
		for _, t in ipairs(s.tags) do
			lines[#lines + 1] = table.concat({
				output,
				t.index,
				t.layout.name,
				t.selected and "1" or "0",
				t.name,
				t.default_name or t.name,
			}, "\t")
		end
	end
	awesome.set_xproperty(TAGS_PROP, table.concat(lines, "\n"))
end

-- restore_tags sets the layouts, selected tags and on-the-fly names screen s
-- had before a restart. Call it right after creating the screen's tags, with
-- t.default_name set on each. A rename is only kept while the configured name
-- is unchanged, so editing settings.lua wins over an old rename
function persist.restore_tags(s)
	local saved = awesome.startup and awesome.get_xproperty(TAGS_PROP)
	if not saved or saved == "" then
		return
	end

	local output = persist.output(s)
	local selected = {}
	for line in saved:gmatch("[^\n]+") do
		local f = split(line)
		local t = f[1] == output and s.tags[position(f[2]) or 0]
		if t then
			local l = layout_by_name(f[3] or "")
			if l then
				t.layout = l
			end
			if f[4] == "1" then
				selected[#selected + 1] = t
			end
			if f[5] and f[6] == t.default_name then
				t.name = f[5]
			end
		end
	end

	if #selected > 0 then
		awful.tag.viewmore(selected, s)
	end
end

-- Put windows back on their monitor and tags. awful.rules has already run (it
-- connected to "manage" first), so this has the last word
client.connect_signal("manage", function(c)
	if not awesome.startup then
		return
	end

	local place = c:get_xproperty(CLIENT_PROP)
	if not place or place == "" then
		return
	end

	local f = split(place)
	local s = screen_by_output(f[1])
	if not s then
		return
	end

	local tags = {}
	for i = 2, #f do
		local t = s.tags[position(f[i]) or 0]
		if t then
			tags[#tags + 1] = t
		end
	end

	if #tags > 0 then
		c.screen = s
		c:tags(tags)
	end
end)

-- Keep the properties current. Nothing is saved during startup, so the values
-- from before the restart aren't overwritten before they're restored
local function on_client_change(c)
	if not awesome.startup then
		save_client(c)
	end
end

client.connect_signal("tagged", on_client_change)
client.connect_signal("untagged", on_client_change)

local function on_tag_change()
	if not awesome.startup then
		save_tags()
	end
end

tag.connect_signal("property::layout", on_tag_change)
tag.connect_signal("property::selected", on_tag_change)
tag.connect_signal("property::name", on_tag_change)

-- Once startup is over (the first main loop iteration), record everything,
-- including windows that had nothing saved
gears.timer.delayed_call(function()
	for _, c in ipairs(client.get()) do
		save_client(c)
	end
	save_tags()
end)

return persist
