-- NVIDIA GPU load and temperature in the bar, from nvidia-smi every 5 s.
-- Yellow from 80 °C or 90% load, red from 87 °C. Hover for VRAM, fan, power
-- and clocks; a click pins the popup
local gears = require("gears")
local awful = require("awful")

local common = require("widgets.common")

local GLYPH = utf8.char(0xf08ae) -- nf-md-expansion_card
local QUERY = "utilization.gpu,temperature.gpu,memory.used,memory.total,fan.speed,power.draw,clocks.gr,clocks.mem,name"

local gpu = {}

local data -- the last reading, or nil
local failed -- nvidia-smi's error, or nil

-- fixed to its widest look, so the numbers never shift the bar
local item = common.bar_item(common.item_markup(GLYPH, "100% 100°"))

local function level()
	if not data then
		return "dim"
	elseif data.temp >= 87 then
		return "bad"
	elseif data.temp >= 80 or data.load >= 90 then
		return "warn"
	end
end

local function render()
	if data then
		item:update(GLYPH, common.pad(data.load .. "%", 4) .. " " .. common.pad(data.temp .. "°", 4), level())
	else
		item:update(GLYPH, "?", "dim")
	end
	item:refresh_popup()
end

local function popup()
	if not data then
		return "nvidia-smi failed:\n" .. common.escape(failed or "no output")
	end
	local lines = {
		"<b>" .. common.escape(data.name) .. "</b>",
		string.format("Load      %d%%", data.load),
		string.format("Temp      %d °C", data.temp),
		string.format("VRAM      %.1f / %.1f GiB (%d%%)", data.mem_used / 1024, data.mem_total / 1024, math.floor(100 * data.mem_used / data.mem_total + 0.5)),
		string.format("Fan       %s", data.fan and (data.fan .. "%") or "n/a"),
		string.format("Power     %s", data.power and string.format("%.0f W", data.power) or "n/a"),
		string.format("Clocks    %d MHz core, %d MHz memory", data.clock_core, data.clock_mem),
	}
	return table.concat(lines, "\n")
end

common.attach_popup(item, popup)

function gpu.refresh()
	awful.spawn.easy_async(
		{ "nvidia-smi", "--query-gpu=" .. QUERY, "--format=csv,noheader,nounits" },
		function(stdout, stderr, _, code)
			local f = {}
			for field in (stdout:match("[^\n]*") .. ","):gmatch("%s*([^,]*),") do
				table.insert(f, field)
			end
			local load, temp = tonumber(f[1]), tonumber(f[2])
			if code ~= 0 or not load or not temp then
				data, failed = nil, (stderr ~= "" and stderr or stdout)
			else
				data = {
					load = load,
					temp = temp,
					mem_used = tonumber(f[3]) or 0,
					mem_total = tonumber(f[4]) or 1,
					fan = tonumber(f[5]), -- "[N/A]" on some cards
					power = tonumber(f[6]),
					clock_core = tonumber(f[7]) or 0,
					clock_mem = tonumber(f[8]) or 0,
					name = f[9] or "GPU",
				}
				failed = nil
			end
			render()
		end
	)
end

gears.timer({ timeout = 5, autostart = true, call_now = true, callback = gpu.refresh })

gpu.widget = item

return gpu
