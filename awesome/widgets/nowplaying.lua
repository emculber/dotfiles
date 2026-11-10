-- What's playing (YouTube in Brave, Spotify...) through playerctl: a play or
-- pause glyph and "Artist – Title", trimmed. Hover for the full title and the
-- player; click to play/pause; scroll for next/previous. Paused shows dimmed
-- and is hidden after 10 minutes; nothing playing hides it
local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi

local common = require("widgets.common")

local MAX_CHARS = 30
local HIDE_PAUSED_AFTER = 600 -- seconds
local FORMAT = "{{playerName}}\t{{status}}\t{{artist}}\t{{title}}"

local GLYPH = {
	playing = utf8.char(0xf040a), -- nf-md-play
	paused = utf8.char(0xf03e4), -- nf-md-pause
}

local nowplaying = {}

local current -- { player, status, artist, title }
local paused_since = {} -- "player\ttitle" -> os.time() when first seen paused

local textbox = common.fixed_text(common.span(nil, GLYPH.playing .. " " .. string.rep("a", MAX_CHARS)))
textbox.align = "left"
local item = wibox.widget({ textbox, left = dpi(6), right = dpi(6), widget = wibox.container.margin })
item.visible = false
local tooltip = awful.tooltip({ objects = { item }, mode = "outside" })

local function trim(text)
	if utf8.len(text) <= MAX_CHARS then
		return text
	end
	return text:sub(1, utf8.offset(text, MAX_CHARS) - 1) .. "…"
end

local function label(p)
	if p.artist ~= "" and p.title ~= "" then
		return p.artist .. " – " .. p.title
	end
	return p.title ~= "" and p.title or p.artist
end

-- friendly turns "brave.instance2657023" into "brave"
local function friendly(player)
	return (player:gsub("%.instance%d+$", ""))
end

local function render()
	if not current then
		item.visible = false
		return
	end
	local level = current.status == "Playing" and nil or "dim"
	local glyph = current.status == "Playing" and GLYPH.playing or GLYPH.paused
	textbox.markup = common.span(level, glyph .. " " .. common.escape(trim(label(current))))
	tooltip.text = string.format("%s\n%s (%s)", label(current), friendly(current.player), current.status:lower())
	item.visible = true
end

-- choose picks what to show from all players: one that plays, else the
-- most recently paused one that hasn't been paused for too long
local function choose(players)
	local now = os.time()
	local seen = {}
	local playing, best, best_since
	for _, p in ipairs(players) do
		if p.status == "Playing" then
			playing = playing or p
		elseif p.status == "Paused" and label(p) ~= "" then
			local key = p.player .. "\t" .. p.title
			seen[key] = true
			paused_since[key] = paused_since[key] or now
			local since = paused_since[key]
			if now - since < HIDE_PAUSED_AFTER and (not best or since > best_since) then
				best, best_since = p, since
			end
		end
	end
	-- forget players that went away or started playing, so a pause later
	-- starts the 10 minutes afresh
	for key in pairs(paused_since) do
		if not seen[key] then
			paused_since[key] = nil
		end
	end
	return playing or best
end

function nowplaying.refresh()
	awful.spawn.easy_async({ "playerctl", "-a", "metadata", "--format", FORMAT }, function(stdout)
		local players = {}
		for line in stdout:gmatch("[^\n]+") do
			local player, status, artist, title = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
			if player then
				table.insert(players, { player = player, status = status, artist = artist, title = title })
			end
		end
		current = choose(players)
		render()
	end)
end

local function control(action)
	if not current then
		return
	end
	awful.spawn.easy_async({ "playerctl", "-p", current.player, action }, function()
		-- the player needs a moment to report its new state
		gears.timer.start_new(0.3, function()
			nowplaying.refresh()
			return false
		end)
	end)
end

item:buttons(gears.table.join(
	awful.button({}, 1, function()
		control("play-pause")
	end),
	awful.button({}, 4, function()
		control("next")
	end),
	awful.button({}, 5, function()
		control("previous")
	end)
))

gears.timer({ timeout = 2, autostart = true, call_now = true, callback = nowplaying.refresh })

nowplaying.widget = item

return nowplaying
