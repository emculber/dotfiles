-- Main menu and the launcher button in the bar
local awful = require("awful")
local beautiful = require("beautiful")
local hotkeys_popup = require("awful.hotkeys_popup")
local menubar = require("menubar")

local settings = require("config.settings")

local debian = require("debian.menu")
local has_fdo, freedesktop = pcall(require, "freedesktop")

local terminal = settings.terminal

local menu = {}

local awesome_items = {
	{
		"hotkeys",
		function()
			hotkeys_popup.show_help(nil, awful.screen.focused())
		end,
	},
	{ "manual", terminal .. " -e man awesome" },
	{ "edit config", settings.editor_cmd .. " " .. awesome.conffile },
	{ "themes", require("modules.theme_switcher").menu() },
	{
		"re-apply displays",
		function()
			require("config.autostart").display_setup()
		end,
	},
	{ "restart", awesome.restart },
	{
		"quit",
		function()
			awesome.quit()
		end,
	},
}

local menu_awesome = { "awesome", awesome_items, beautiful.awesome_icon }
local menu_terminal = { "open terminal", terminal }

if has_fdo then
	menu.main = freedesktop.menu.build({
		before = { menu_awesome },
		after = { menu_terminal },
	})
else
	menu.main = awful.menu({
		items = {
			menu_awesome,
			{ "Debian", debian.menu.Debian_menu.Debian },
			menu_terminal,
		},
	})
end

menu.launcher = awful.widget.launcher({ image = beautiful.awesome_icon, menu = menu.main })

-- Set the terminal for applications that require it
menubar.utils.terminal = terminal

return menu
