-- A drop-down terminal: Mod+` shows a floating kitty centred on the focused
-- monitor, and hides it again. It keeps running while hidden, so whatever is
-- in it stays. The window is recognised by its class, "scratchpad"
local awful = require("awful")

local settings = require("config.settings")

local CLASS = "scratchpad"

local scratchpad = {}

local function find()
	for _, c in ipairs(client.get()) do
		if c.class == CLASS then
			return c
		end
	end
end

-- show brings c to the focused monitor's current tag, centred, on top
local function show(c)
	local s = awful.screen.focused()
	c.hidden = false
	c:move_to_screen(s)
	c:move_to_tag(s.selected_tag)
	local area = s.workarea
	c:geometry({ width = math.floor(area.width * 0.6), height = math.floor(area.height * 0.5) })
	awful.placement.centered(c, { honor_workarea = true })
	c:emit_signal("request::activate", "scratchpad", { raise = true })
end

function scratchpad.toggle()
	local c = find()
	if not c then
		-- the rule below (added in config/rules.lua) shows it once it opens
		awful.spawn({ settings.terminal, "--class", CLASS })
	elseif c == client.focus and not c.hidden then
		c.hidden = true
	else
		show(c)
	end
end

-- the rule config/rules.lua adds for it
scratchpad.rule = {
	rule = { class = CLASS },
	properties = { floating = true, ontop = true, skip_taskbar = true, titlebars_enabled = false },
	callback = show,
}

return scratchpad
