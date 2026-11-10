-- ClamAV status in the bar: the three scheduled scans (~/.local/bin/clamav-*-scan.sh),
-- quarantine, signature freshness and clamd. Data comes from
-- scripts/clamav-status.sh. Hover for details, click to pin, right-click for
-- actions
local gears = require("gears")
local awful = require("awful")

local common = require("widgets.common")
local settings = require("config.settings")

local GLYPH = utf8.char(0xf0483) -- nf-md-security (shield)
local HOME = os.getenv("HOME")
local STATE = HOME .. "/.local/share/clamav/"
local DB_STALE_AFTER = 48 * 3600
local RECENT = 7 * 86400 -- an infection this recent turns the icon red

local JOBS = {
	{ key = "quick", log = "quick", title = "Quick scan", what = "daily: Downloads, Desktop, Documents, /tmp", overdue = 26 * 3600 },
	{ key = "full_home", log = "full-home", title = "Full home scan", what = "weekly: all of ~", overdue = 8 * 86400 },
	{ key = "mnt", log = "mnt", title = "NAS / disk scan", what = "monthly: /mnt", overdue = 33 * 86400 },
}

local clamav = {}

local item = common.bar_item()
local data = {}
local refresh

local function job_field(job, field)
	return data[job.key .. "_" .. field]
end

-- problems returns the bar level, the bar text and a list of reasons
local function problems()
	local level, reasons = "ok", {}
	local function raise(new, reason)
		local rank = { ok = 0, warn = 1, bad = 2 }
		if rank[new] > rank[level] then
			level = new
		end
		table.insert(reasons, reason)
	end

	local quarantined = tonumber(data.quarantine_count) or 0
	if quarantined > 0 then
		raise("bad", quarantined .. " file(s) in quarantine")
	end

	local running = false
	for _, job in ipairs(JOBS) do
		if job_field(job, "running") == "1" then
			running = true
		end
		local finished = common.time(job_field(job, "end"))
		local infected = tonumber(job_field(job, "infected")) or 0
		if infected > 0 and finished and os.time() - finished < RECENT then
			raise("bad", job.title .. " found " .. infected .. " infected")
		end
		if not finished or os.time() - finished > job.overdue then
			raise("warn", job.title .. " is overdue")
		end
	end

	if data.clamd ~= "active" then
		raise("warn", "clamd is " .. (data.clamd or "unknown"))
	end
	local built = tonumber(data.db_built_epoch)
	if not built or os.time() - built > DB_STALE_AFTER then
		raise("warn", "signatures are out of date")
	end

	if running and level == "ok" then
		return "accent", "scan", reasons
	end
	local text = level == "bad" and "!" or level == "warn" and "!" or ""
	return level, text, reasons
end

local function row(label, value)
	return string.format("%-13s %s", label, value)
end

local function build()
	local _, _, reasons = problems()
	local lines = { "<b>ClamAV</b>" }
	for _, reason in ipairs(reasons) do
		local level = (reason:find("infected") or reason:find("quarantine")) and "bad" or "warn"
		table.insert(lines, common.span(level, "! " .. common.escape(reason)))
	end

	table.insert(lines, row("clamd", common.span(data.clamd == "active" and "ok" or "warn", common.escape(data.clamd or "?"))))
	local built = tonumber(data.db_built_epoch)
	table.insert(lines, row("Signatures", string.format("v%s, built %s ago", data.db_version or "?", built and common.ago(os.time() - built) or "?")))
	if data.clamav_update then
		table.insert(lines, row("Update", common.span("warn", "ClamAV " .. common.escape(data.clamav_update) .. " is available")))
	end
	local quarantined = tonumber(data.quarantine_count) or 0
	table.insert(lines, row("Quarantine", common.span(quarantined > 0 and "bad" or nil, quarantined .. " file(s)")))
	for _, file in ipairs(common.list(data.quarantine_file)) do
		table.insert(lines, "  " .. common.escape(file))
	end

	for _, job in ipairs(JOBS) do
		table.insert(lines, "")
		table.insert(lines, "<b>" .. job.title .. "</b> (" .. job.what .. ")")
		local start = job_field(job, "start")
		if job_field(job, "running") == "1" then
			table.insert(lines, row("  Status", common.span("accent", "running since " .. (start or "?"):sub(1, 16))))
		elseif start then
			-- "281168.976 sec (4686 m 8 s)": show long scans as hours
			local seconds = tonumber((job_field(job, "time") or ""):match("^([%d.]+) sec"))
			local took
			if seconds and seconds >= 3600 then
				took = string.format("%dh %02dm", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
			elseif seconds then
				took = string.format("%dm %02ds", math.floor(seconds / 60), math.floor(seconds % 60))
			end
			table.insert(lines, row("  Last", start:sub(1, 16) .. (took and ("  took " .. took) or "")))
			local infected = tonumber(job_field(job, "infected"))
			local errors = tonumber(job_field(job, "errors")) or 0
			local result
			if job_field(job, "note") then
				result = common.escape(job_field(job, "note"))
			elseif infected and infected > 0 then
				result = common.span("bad", infected .. " infected")
			elseif infected then
				result = common.span("ok", "clean")
			else
				result = "exit " .. (job_field(job, "exit") or "?")
			end
			if errors > 0 then
				result = result .. common.span("dim", string.format(" (%d unreadable file(s) skipped)", errors))
			end
			table.insert(lines, row("  Result", result))
		else
			table.insert(lines, row("  Last", common.span("warn", "never")))
		end
		table.insert(lines, row("  Next", common.escape(job_field(job, "next") or "?")))
	end
	return table.concat(lines, "\n")
end

local function update(new)
	data = new
	local level, text = problems()
	item:update(GLYPH, text, level)
	item:refresh_popup()
end

common.attach_popup(item, build)

local function open_log(job)
	return function()
		awful.spawn({ settings.terminal, "-e", "less", "+G", STATE .. job.log .. ".log" })
	end
end

item:buttons(gears.table.join(item:buttons(), awful.button({}, 3, function()
	common.menu({
		{
			"Run quick scan now",
			function()
				awful.spawn.easy_async({ "systemctl", "--user", "start", "--no-block", "clamav-quick-scan.service" }, function()
					refresh()
				end)
			end,
		},
		{
			"Open quarantine folder",
			function()
				awful.spawn({ "xdg-open", HOME .. "/Quarantine" })
			end,
		},
		{ "Quick scan log", open_log(JOBS[1]) },
		{ "Full home scan log", open_log(JOBS[2]) },
		{ "NAS / disk scan log", open_log(JOBS[3]) },
		{
			"Refresh",
			function()
				refresh()
			end,
		},
	})
end)))

refresh = common.watch("clamav-status.sh", 300, update)
-- refresh as soon as a run starts or ends, not just every 5 minutes
common.watch_units(
	{ "clamav-quick-scan.service", "clamav-full-home-scan.service", "clamav-mnt-scan.service" },
	function()
		refresh()
	end
)

-- check more often while a scan runs, to catch the end quickly
gears.timer({
	timeout = 30,
	autostart = true,
	callback = function()
		for _, job in ipairs(JOBS) do
			if job_field(job, "running") == "1" then
				return refresh()
			end
		end
	end,
})

clamav.widget = item
clamav.refresh = refresh

return clamav
