-- Proton VPN in the bar, through the protonvpn CLI. The icon is green while
-- connected, dim when not, accent while connecting; hover shows the server.
-- Left click connects to the fastest server or disconnects; right click opens
-- a panel with the status, countries (settings.vpn.countries), P2P, Secure
-- Core and so on.
-- The status comes from NetworkManager: Proton's connection is "ProtonVPN
-- <server>" on the device proton0 (WireGuard and OpenVPN alike).
-- The CLI refuses to run while the Proton VPN app is open; that is reported
local gears = require("gears")
local awful = require("awful")
local naughty = require("naughty")

local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi

local common = require("widgets.common")
local settings = require("config.settings")

local GLYPH = utf8.char(0xf0582) -- nf-md-vpn
local ICON = {
	connect = utf8.char(0xf0425), -- nf-md-power
	disconnect = utf8.char(0xf0338), -- nf-md-link_variant_off
	p2p = utf8.char(0xf04e1), -- nf-md-swap_horizontal
	securecore = utf8.char(0xf099d), -- nf-md-shield_lock
	tor = utf8.char(0xf05f9), -- nf-md-incognito
	random = utf8.char(0xf076e), -- nf-md-dice_multiple
}

-- names for the panel; any other code still works, shown as the code
local COUNTRY = {
	US = "United States", CA = "Canada", CH = "Switzerland", NL = "Netherlands",
	GB = "United Kingdom", UK = "United Kingdom", DE = "Germany", FR = "France",
	SE = "Sweden", NO = "Norway", IS = "Iceland", JP = "Japan", AU = "Australia",
	ES = "Spain", IT = "Italy", MX = "Mexico", BR = "Brazil", SG = "Singapore",
}
local DEVICE = "proton0"
local APP_RUNNING = "desktop app is currently running"

local cfg = settings.vpn or {}

local vpn = {}

local item = common.bar_item()
local tooltip = awful.tooltip({ objects = { item }, mode = "outside" })

local state = {
	server = nil, -- e.g. "US#123" while connected
	busy = nil, -- "connecting" / "disconnecting" while the CLI runs
}

local panel -- the right-click panel, built on demand

local function render()
	if panel and panel.visible then
		panel:sync()
	end
	if state.busy then
		item:update(GLYPH, nil, "accent")
		tooltip.text = "Proton VPN: " .. state.busy .. "…"
	elseif state.server then
		item:update(GLYPH, nil, "ok")
		tooltip.text = "Proton VPN: connected to " .. state.server
	else
		item:update(GLYPH, nil, "dim")
		tooltip.text = "Proton VPN: disconnected (click to connect)"
	end
end

-- refresh reads the active connections from NetworkManager
function vpn.refresh(callback)
	awful.spawn.easy_async({ "nmcli", "-t", "-f", "NAME,DEVICE", "connection", "show", "--active" }, function(stdout)
		state.server = nil
		for line in stdout:gmatch("[^\n]+") do
			local name, device = line:match("^(.*):([^:]*)$")
			if device == DEVICE then
				-- nmcli -t escapes ':' in names as '\:'
				state.server = (name:gsub("\\:", ":"):gsub("^ProtonVPN ", ""))
			end
		end
		render()
		if callback then
			callback()
		end
	end)
end

local function notify(title, text, critical)
	naughty.notify({
		title = title,
		text = text,
		preset = critical and naughty.config.presets.critical or nil,
		timeout = critical and 0 or 4,
	})
end

-- run runs a protonvpn command, then reports the outcome. busy is what the
-- tooltip says meanwhile
local function run(args, busy)
	local cmd = { "protonvpn" }
	for _, a in ipairs(args) do
		table.insert(cmd, a)
	end
	state.busy = busy
	render()
	awful.spawn.easy_async(cmd, function(stdout, stderr, _, code)
		state.busy = nil
		local output = (stdout .. "\n" .. stderr):gsub("%s+$", "")
		vpn.refresh(function()
			if output:find(APP_RUNNING, 1, true) then
				notify("Proton VPN", "Close the Proton VPN app first: the command line and the app can't run at the same time.", true)
			elseif code ~= 0 then
				notify("Proton VPN: " .. table.concat(args, " ") .. " failed", output:sub(-400), true)
			elseif state.server then
				notify("Proton VPN", "Connected to " .. state.server)
			else
				notify("Proton VPN", "Disconnected")
			end
		end)
	end)
end

function vpn.connect(...)
	run({ "connect", ... }, "connecting")
end

function vpn.disconnect()
	run({ "disconnect" }, "disconnecting")
end

function vpn.toggle()
	if state.busy then
		return
	elseif state.server then
		vpn.disconnect()
	else
		vpn.connect()
	end
end

-- flag returns the emoji flag for a two-letter country code. It needs the
-- Noto Color Emoji font: the default fallback (FreeSans) draws plain letters
local function flag(code)
	if not code:match("^%a%a$") then
		return ""
	end
	code = code:upper() == "UK" and "GB" or code:upper()
	local chars = utf8.char(0x1F1E6 + code:byte(1) - 65, 0x1F1E6 + code:byte(2) - 65)
	return '<span font_family="Noto Color Emoji">' .. chars .. "</span> "
end

local function build_panel()
	local status = wibox.widget({ widget = wibox.widget.textbox })
	local action = wibox.layout.fixed.vertical()
	local p

	-- run_then_close returns a click handler that hides the panel and runs f
	local function run_then_close(f, ...)
		local args = { ... }
		return function()
			p.visible = false
			f(table.unpack(args))
		end
	end

	local countries = wibox.layout.fixed.vertical()
	for _, code in ipairs(cfg.countries or {}) do
		local name = COUNTRY[code:upper()] or code
		countries:add(common.row(flag(code) .. common.escape(name), run_then_close(vpn.connect, "--country", code)))
	end

	local types = wibox.layout.fixed.vertical()
	for _, t in ipairs({
		{ ICON.p2p, "P2P", "--p2p" },
		{ ICON.securecore, "Secure Core", "--securecore" },
		{ ICON.tor, "Tor", "--tor" },
		{ ICON.random, "Random server", "--random" },
	}) do
		types:add(common.row(common.span("dim", t[1]) .. "  " .. t[2], run_then_close(vpn.connect, t[3])))
	end

	p = common.panel({
		common.heading("Proton VPN", true),
		{ status, top = dpi(2), bottom = dpi(6), widget = wibox.container.margin },
		action,
		common.heading("Quick connect"),
		countries,
		common.heading("Server type"),
		types,
		{
			common.row(
				common.span("dim", "Open Proton VPN app…\n<small>close it again to use the bar</small>"),
				run_then_close(awful.spawn, "protonvpn-app")
			),
			top = dpi(8),
			widget = wibox.container.margin,
		},
		forced_width = dpi(190),
		layout = wibox.layout.fixed.vertical,
	})

	-- sync redraws the status line and the main action from state
	function p:sync()
		if state.busy then
			status.markup = common.span("accent", "◌ " .. state.busy:gsub("^%l", string.upper) .. "…")
		elseif state.server then
			status.markup = common.span("ok", "● Connected") .. "  " .. common.escape(state.server)
		else
			status.markup = common.span("dim", "○ Disconnected")
		end

		action:reset()
		if state.busy then
			action:add(common.row(common.span("dim", "Working…")))
		elseif state.server then
			action:add(common.row(common.span("bad", ICON.disconnect) .. "  <b>Disconnect</b>", run_then_close(vpn.disconnect)))
		else
			action:add(common.row(common.span("ok", ICON.connect) .. "  <b>Connect</b>  " .. common.span("dim", "fastest server"), run_then_close(vpn.connect)))
		end
	end

	return p
end

local function toggle_panel()
	panel = panel or build_panel()
	if panel.visible then
		panel.visible = false
		return
	end
	local geometry = mouse.current_widget_geometry
	vpn.refresh(function()
		panel:sync()
		panel:show_at(geometry)
	end)
end

item:buttons(gears.table.join(awful.button({}, 1, vpn.toggle), awful.button({}, 3, toggle_panel)))

vpn.refresh()
gears.timer({ timeout = 5, autostart = true, callback = function() vpn.refresh() end })

vpn.widget = item

return vpn
