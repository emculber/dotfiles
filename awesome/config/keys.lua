-- Key bindings: global keys, client keys and tag number keys
local gears = require("gears")
local awful = require("awful")
local naughty = require("naughty")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
-- Enable hotkeys help widget for VIM and other apps
-- when client with a matching name is opened:
require("awful.hotkeys_popup.keys")

local settings = require("config.settings")
local menu = require("config.menu")

local modkey = settings.modkey
local terminal = settings.terminal

local keys = {}

-- screenshot runs scrot with args ("" = everything, or "--select --freeze")
-- into ~/Pictures/Screenshots, then shows the shot in a notification
local function screenshot(args)
	local dir = os.getenv("HOME") .. "/Pictures/Screenshots/"
	local file = dir .. os.date("%Y-%m-%d_%H-%M-%S") .. ".png"
	-- the short sleep lets the key go up first: scrot can't grab the pointer
	-- for --select while awesome still holds the keyboard
	local cmd = string.format("mkdir -p '%s' && sleep 0.2 && scrot %s '%s'", dir, args, file)
	awful.spawn.easy_async_with_shell(cmd, function(_, stderr, _, code)
		if code == 0 then
			naughty.notify({ title = "Screenshot", text = file, icon = file, timeout = 4 })
		elseif not (stderr:lower():find("abort") or stderr:lower():find("cancel")) then -- Esc during --select
			naughty.notify({ preset = naughty.config.presets.critical, title = "Screenshot failed", text = stderr })
		end
	end)
end

keys.global = gears.table.join(
	awful.key({ modkey }, "s", hotkeys_popup.show_help, { description = "show help", group = "awesome" }),
	awful.key({ modkey }, "Left", awful.tag.viewprev, { description = "view previous", group = "tag" }),
	awful.key({ modkey }, "Right", awful.tag.viewnext, { description = "view next", group = "tag" }),
	awful.key({ modkey }, "Escape", awful.tag.history.restore, { description = "go back", group = "tag" }),

	awful.key({ modkey }, "j", function()
		awful.client.focus.byidx(1)
	end, { description = "focus next by index", group = "client" }),
	awful.key({ modkey }, "k", function()
		awful.client.focus.byidx(-1)
	end, { description = "focus previous by index", group = "client" }),
	awful.key({ modkey }, "w", function()
		menu.main:show()
	end, { description = "show main menu", group = "awesome" }),

	-- Layout manipulation
	awful.key({ modkey, "Shift" }, "j", function()
		awful.client.swap.byidx(1)
	end, { description = "swap with next client by index", group = "client" }),
	awful.key({ modkey, "Shift" }, "k", function()
		awful.client.swap.byidx(-1)
	end, { description = "swap with previous client by index", group = "client" }),
	awful.key({ modkey, "Control" }, "j", function()
		awful.screen.focus_relative(1)
	end, { description = "focus the next screen", group = "screen" }),
	awful.key({ modkey, "Control" }, "k", function()
		awful.screen.focus_relative(-1)
	end, { description = "focus the previous screen", group = "screen" }),
	awful.key({ modkey }, "u", awful.client.urgent.jumpto, { description = "jump to urgent client", group = "client" }),
	awful.key({ modkey }, "Tab", function()
		awful.client.focus.history.previous()
		if client.focus then
			client.focus:raise()
		end
	end, { description = "go back", group = "client" }),

	-- Standard program
	awful.key({ modkey }, "Return", function()
		awful.spawn(terminal)
	end, { description = "open a terminal", group = "launcher" }),
	awful.key({ modkey, "Control" }, "r", awesome.restart, { description = "reload awesome", group = "awesome" }),
	awful.key({ modkey, "Shift" }, "q", awesome.quit, { description = "quit awesome", group = "awesome" }),

	awful.key({ modkey }, "l", function()
		awful.tag.incmwfact(0.05)
	end, { description = "increase master width factor", group = "layout" }),
	awful.key({ modkey }, "h", function()
		awful.tag.incmwfact(-0.05)
	end, { description = "decrease master width factor", group = "layout" }),
	awful.key({ modkey, "Shift" }, "h", function()
		awful.tag.incnmaster(1, nil, true)
	end, { description = "increase the number of master clients", group = "layout" }),
	awful.key({ modkey, "Shift" }, "l", function()
		awful.tag.incnmaster(-1, nil, true)
	end, { description = "decrease the number of master clients", group = "layout" }),
	awful.key({ modkey, "Control" }, "h", function()
		awful.tag.incncol(1, nil, true)
	end, { description = "increase the number of columns", group = "layout" }),
	awful.key({ modkey, "Control" }, "l", function()
		awful.tag.incncol(-1, nil, true)
	end, { description = "decrease the number of columns", group = "layout" }),
	awful.key({ modkey }, "space", function()
		awful.layout.inc(1)
	end, { description = "select next", group = "layout" }),
	awful.key({ modkey, "Shift" }, "space", function()
		awful.layout.inc(-1)
	end, { description = "select previous", group = "layout" }),

	awful.key({ modkey, "Control" }, "n", function()
		local c = awful.client.restore()
		-- Focus restored client
		if c then
			c:emit_signal("request::activate", "key.unminimize", { raise = true })
		end
	end, { description = "restore minimized", group = "client" }),

	-- Prompt
	awful.key({ modkey }, "r", function()
		awful.screen.focused().mypromptbox:run()
	end, { description = "run prompt", group = "launcher" }),

	awful.key({ modkey }, "x", function()
		awful.prompt.run({
			prompt = "Run Lua code: ",
			textbox = awful.screen.focused().mypromptbox.widget,
			exe_callback = awful.util.eval,
			history_path = awful.util.get_cache_dir() .. "/history_eval",
		})
	end, { description = "lua execute prompt", group = "awesome" }),
	-- Menubar
	awful.key({ modkey }, "p", function()
		menubar.show()
	end, { description = "show the menubar", group = "launcher" }),
	-- Media keys (widgets/volume.lua, playerctl)
	awful.key({}, "XF86AudioRaiseVolume", function()
		require("widgets.volume").up(true)
	end, { description = "volume up", group = "media" }),
	awful.key({}, "XF86AudioLowerVolume", function()
		require("widgets.volume").down(true)
	end, { description = "volume down", group = "media" }),
	awful.key({}, "XF86AudioMute", function()
		require("widgets.volume").toggle_mute(true)
	end, { description = "mute", group = "media" }),
	awful.key({}, "XF86AudioMicMute", function()
		require("widgets.volume").toggle_mic(true)
	end, { description = "mute microphone", group = "media" }),
	awful.key({ modkey }, "bracketright", function()
		require("widgets.volume").up(true)
	end, { description = "volume up", group = "media" }),
	awful.key({ modkey }, "bracketleft", function()
		require("widgets.volume").down(true)
	end, { description = "volume down", group = "media" }),
	awful.key({}, "XF86AudioPlay", function()
		awful.spawn({ "playerctl", "play-pause" })
	end, { description = "play/pause", group = "media" }),
	awful.key({}, "XF86AudioNext", function()
		awful.spawn({ "playerctl", "next" })
	end, { description = "next track", group = "media" }),
	awful.key({}, "XF86AudioPrev", function()
		awful.spawn({ "playerctl", "previous" })
	end, { description = "previous track", group = "media" }),

	-- Tags, scratchpad, screenshots
	awful.key({ modkey, "Shift" }, "r", function()
		local s = awful.screen.focused()
		local t = s.selected_tag
		if not t then
			return
		end
		awful.prompt.run({
			prompt = "Rename tag " .. t.index .. ": ",
			text = (t.name:gsub("^%d+:?", "")),
			textbox = s.mypromptbox.widget,
			exe_callback = function(name)
				name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
				t.name = name ~= "" and (t.index .. ":" .. name) or tostring(t.index)
			end,
		})
	end, { description = "rename the current tag (empty = number only)", group = "tag" }),
	awful.key({ modkey }, "grave", function()
		require("modules.scratchpad").toggle()
	end, { description = "drop-down terminal", group = "launcher" }),
	awful.key({}, "Print", function()
		screenshot("")
	end, { description = "screenshot", group = "screenshot" }),
	awful.key({ modkey, "Shift" }, "s", function()
		screenshot("--select --freeze")
	end, { description = "screenshot of a region", group = "screenshot" }),

	-- Sleep
	awful.key({ modkey }, "F8", function()
		awful.spawn("systemctl suspend")
	end, { description = "suspend", group = "custom" }),
	-- Screen colour temperature (modules/idle_dim.lua)
	awful.key({ modkey }, "F11", function()
		require("modules.idle_dim").shift_temp(-100)
	end, { description = "warmer screen (-100 K)", group = "custom" }),
	awful.key({ modkey }, "F12", function()
		require("modules.idle_dim").shift_temp(100)
	end, { description = "cooler screen (+100 K)", group = "custom" }),
	awful.key({ modkey }, "F10", function()
		require("modules.idle_dim").reset_temp()
	end, { description = "screen temperature back to schedule", group = "custom" })
)

keys.client = gears.table.join(
	awful.key({ modkey }, "f", function(c)
		c.fullscreen = not c.fullscreen
		c:raise()
	end, { description = "toggle fullscreen", group = "client" }),
	awful.key({ modkey, "Shift" }, "c", function(c)
		c:kill()
	end, { description = "close", group = "client" }),
	awful.key(
		{ modkey, "Control" },
		"space",
		awful.client.floating.toggle,
		{ description = "toggle floating", group = "client" }
	),
	awful.key({ modkey, "Control" }, "Return", function(c)
		c:swap(awful.client.getmaster())
	end, { description = "move to master", group = "client" }),
	awful.key({ modkey }, "o", function(c)
		c:move_to_screen()
	end, { description = "move to screen", group = "client" }),
	awful.key({ modkey }, "t", function(c)
		c.ontop = not c.ontop
	end, { description = "toggle keep on top", group = "client" }),
	awful.key({ modkey }, "n", function(c)
		-- The client currently has the input focus, so it cannot be
		-- minimized, since minimized clients can't have the focus.
		c.minimized = true
	end, { description = "minimize", group = "client" }),
	awful.key({ modkey }, "m", function(c)
		c.maximized = not c.maximized
		c:raise()
	end, { description = "(un)maximize", group = "client" }),
	awful.key({ modkey, "Control" }, "m", function(c)
		c.maximized_vertical = not c.maximized_vertical
		c:raise()
	end, { description = "(un)maximize vertically", group = "client" }),
	awful.key({ modkey, "Shift" }, "m", function(c)
		c.maximized_horizontal = not c.maximized_horizontal
		c:raise()
	end, { description = "(un)maximize horizontally", group = "client" })
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it work on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 9 do
	keys.global = gears.table.join(
		keys.global,
		-- View tag only.
		awful.key({ modkey }, "#" .. i + 9, function()
			local screen = awful.screen.focused()
			local tag = screen.tags[i]
			if tag then
				tag:view_only()
			end
		end, { description = "view tag #" .. i, group = "tag" }),
		-- Toggle tag display.
		awful.key({ modkey, "Control" }, "#" .. i + 9, function()
			local screen = awful.screen.focused()
			local tag = screen.tags[i]
			if tag then
				awful.tag.viewtoggle(tag)
			end
		end, { description = "toggle tag #" .. i, group = "tag" }),
		-- Move client to tag.
		awful.key({ modkey, "Shift" }, "#" .. i + 9, function()
			if client.focus then
				local tag = client.focus.screen.tags[i]
				if tag then
					client.focus:move_to_tag(tag)
				end
			end
		end, { description = "move focused client to tag #" .. i, group = "tag" }),
		-- Toggle tag on focused client.
		awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9, function()
			if client.focus then
				local tag = client.focus.screen.tags[i]
				if tag then
					client.focus:toggle_tag(tag)
				end
			end
		end, { description = "toggle focused client on tag #" .. i, group = "tag" })
	)
end

root.keys(keys.global)

return keys
