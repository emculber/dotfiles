-- Builds a full beautiful theme from a palette (themes/palettes/*.lua), so a
-- new theme is just a dozen colours. Palette keys:
--   bg       bar, menus and popups
--   bg_alt   unfocused titlebars and window borders, a shade off bg
--   surface  selected rows, the focused task, hover
--   fg       text
--   fg_dim   empty tags, inactive text
--   accent   focused tag, focused border, highlights
--   accent2  secondary highlight (urgent-free emphasis, e.g. marked)
--   red, yellow, green  urgent / warning / ok
local gears = require("gears")
local theme_assets = require("beautiful.theme_assets")
local dpi = require("beautiful.xresources").apply_dpi

local settings = require("config.settings")

local default_dir = gears.filesystem.get_themes_dir() .. "default/"

return function(p)
	local theme = {}

	theme.name = p.name
	theme.palette = p
	theme.font = settings.font

	theme.bg_normal = p.bg
	theme.bg_focus = p.surface
	theme.bg_urgent = p.red
	theme.bg_minimize = p.bg
	theme.bg_systray = p.bg

	theme.fg_normal = p.fg
	theme.fg_focus = p.fg
	theme.fg_urgent = p.bg
	theme.fg_minimize = p.fg_dim

	theme.useless_gap = dpi(4)
	theme.gap_single_client = false
	theme.border_width = dpi(2)
	theme.border_normal = p.bg_alt
	theme.border_focus = p.accent
	theme.border_marked = p.accent2

	theme.wibar_height = settings.bar_height

	-- taglist: the 1-9 boxes
	theme.taglist_bg_focus = p.accent
	theme.taglist_fg_focus = p.bg
	theme.taglist_fg_occupied = p.fg
	theme.taglist_fg_empty = p.fg_dim
	theme.taglist_bg_urgent = p.red
	theme.taglist_fg_urgent = p.bg
	local square = dpi(4)
	theme.taglist_squares_sel = theme_assets.taglist_squares_sel(square, p.bg)
	theme.taglist_squares_unsel = theme_assets.taglist_squares_unsel(square, p.fg_dim)

	-- tasklist: the window titles in the middle of the bar
	theme.tasklist_bg_normal = p.bg
	theme.tasklist_fg_normal = p.fg_dim
	theme.tasklist_bg_focus = p.surface
	theme.tasklist_fg_focus = p.fg
	theme.tasklist_bg_urgent = p.red
	theme.tasklist_fg_urgent = p.bg

	theme.titlebar_bg_normal = p.bg_alt
	theme.titlebar_fg_normal = p.fg_dim
	theme.titlebar_bg_focus = p.surface
	theme.titlebar_fg_focus = p.fg

	theme.menu_bg_normal = p.bg
	theme.menu_fg_normal = p.fg
	theme.menu_bg_focus = p.surface
	theme.menu_fg_focus = p.accent
	theme.menu_border_color = p.surface
	theme.menu_border_width = dpi(1)
	theme.menu_height = dpi(22)
	theme.menu_width = dpi(200)
	theme.menu_submenu_icon = default_dir .. "submenu.png"

	theme.tooltip_bg = p.bg
	theme.tooltip_fg = p.fg
	theme.tooltip_border_color = p.surface
	theme.tooltip_border_width = dpi(1)

	theme.prompt_bg = p.bg
	theme.prompt_fg = p.accent
	theme.prompt_bg_cursor = p.accent
	theme.prompt_fg_cursor = p.bg

	theme.hotkeys_bg = p.bg
	theme.hotkeys_fg = p.fg
	theme.hotkeys_border_color = p.accent
	theme.hotkeys_border_width = dpi(1)
	theme.hotkeys_modifiers_fg = p.fg_dim
	theme.hotkeys_label_bg = p.accent
	theme.hotkeys_label_fg = p.bg
	theme.hotkeys_group_margin = dpi(16)
	theme.hotkeys_shape = function(cr, w, h)
		gears.shape.rounded_rect(cr, w, h, dpi(8))
	end

	-- notifications (refined further in config/notifications.lua)
	theme.notification_bg = p.bg
	theme.notification_fg = p.fg
	theme.notification_border_color = p.accent
	theme.notification_border_width = dpi(1)
	theme.notification_margin = dpi(10)
	theme.notification_icon_size = dpi(32)
	theme.notification_max_width = dpi(260)
	theme.notification_shape = function(cr, w, h)
		gears.shape.rounded_rect(cr, w, h, dpi(8))
	end

	-- the calendar popup on the clock
	theme.calendar_style = { bg_color = p.bg, fg_color = p.fg, border_color = p.surface, border_width = 0 }
	theme.calendar_month_border_width = dpi(1)
	theme.calendar_header_fg_color = p.accent
	theme.calendar_weekday_fg_color = p.fg_dim
	theme.calendar_focus_bg_color = p.accent
	theme.calendar_focus_fg_color = p.bg

	-- stock icons, recoloured to match
	for _, state in ipairs({ "normal", "focus" }) do
		for _, button in ipairs({ "close", "minimize" }) do
			theme["titlebar_" .. button .. "_button_" .. state] = default_dir .. "titlebar/" .. button .. "_" .. state .. ".png"
		end
		for _, button in ipairs({ "ontop", "sticky", "floating", "maximized" }) do
			for _, active in ipairs({ "inactive", "active" }) do
				theme["titlebar_" .. button .. "_button_" .. state .. "_" .. active] = default_dir
					.. "titlebar/" .. button .. "_" .. state .. "_" .. active .. ".png"
			end
		end
	end
	theme_assets.recolor_titlebar(theme, p.fg_dim, "normal")
	theme_assets.recolor_titlebar(theme, p.accent, "focus")

	for _, layout in ipairs({
		"fairh", "fairv", "floating", "magnifier", "max", "fullscreen", "tilebottom",
		"tileleft", "tile", "tiletop", "spiral", "dwindle", "cornernw", "cornerne", "cornersw", "cornerse",
	}) do
		theme["layout_" .. layout] = default_dir .. "layouts/" .. layout .. "w.png"
	end
	theme_assets.recolor_layout(theme, p.fg)

	theme.awesome_icon = theme_assets.awesome_icon(theme.menu_height, p.accent, p.bg)

	-- monitors without a wallpaper in settings.screens get a plain background
	theme.wallpaper = nil

	return theme
end
