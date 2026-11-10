-- Backup status in the bar: borg (nightly, ~/.local/bin/borg-backup.sh) and the
-- monthly pg_dumpall in ~/database. Data comes from scripts/backup-status.sh.
-- Bar: an icon coloured by status (green ok, yellow stale, red failed). Hover
-- for details, click to pin, right-click for actions
local gears = require("gears")
local awful = require("awful")

local common = require("widgets.common")
local settings = require("config.settings")

local GLYPH = utf8.char(0xf006f) -- nf-md-backup_restore
local STALE_AFTER = 26 * 3600 -- the timer runs daily; a little slack
local PG_STALE_AFTER = 40 * 86400 -- monthly dump
local LOG = os.getenv("HOME") .. "/.local/share/borg/backup.log"

local backup = {}

local item = common.bar_item()
local data = {}
local refresh

local function short(ts)
	return ts and ts:sub(1, 16) or "never"
end

local function duration(start, finish)
	local s, f = common.time(start), common.time(finish)
	if not (s and f) then
		return ""
	end
	local d = f - s
	if d < 60 then
		return d .. "s"
	end
	return string.format("%dm%02ds", math.floor(d / 60), d % 60)
end

local function commas(n)
	return tostring(n or "?"):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

-- status returns the bar level: dim (no data), accent (running), bad (last
-- run failed), warn (stale borg backup or Postgres dump), ok
local function status()
	if data.error then
		return "dim"
	end
	local ok_age = data.ok_end and os.time() - common.time(data.ok_end)
	if data.last_result == "running" or data.running == "activating" then
		return "accent"
	elseif data.last_result == "failed" then
		return "bad"
	elseif not ok_age or ok_age > STALE_AFTER then
		return "warn"
	end
	local pg = data.pg_date and common.time(data.pg_date)
	if not pg or os.time() - pg > PG_STALE_AFTER then
		return "warn"
	end
	return "ok"
end

local function row(label, value)
	return string.format("%-13s %s", label, value)
end

local function build()
	if data.error then
		return common.span("bad", common.escape(data.error))
	end
	local lines = { "<b>Borg backup</b>" }
	local result = data.last_result or "?"
	local level = ({ ok = "ok", failed = "bad", running = "accent" })[result]
	table.insert(lines, row("Last run", short(data.last_start) .. "  " .. common.span(level, result)))
	if data.ok_end then
		table.insert(lines, row("Last success", short(data.ok_end) .. "  (" .. common.ago(os.time() - common.time(data.ok_end)) .. " ago)"))
	else
		table.insert(lines, row("Last success", common.span("bad", "none in the log")))
	end
	table.insert(lines, row("Next run", common.escape(data.next or "?")))
	local fails = tonumber(data.fails_since_ok) or 0
	if fails > 0 then
		table.insert(lines, row("Failures", common.span("bad", fails .. " since the last success")))
	end
	if data.last_error then
		table.insert(lines, row("Error", common.span("bad", common.escape(data.last_error:sub(1, 90)))))
	end

	if data.ok_start then
		table.insert(lines, "")
		table.insert(lines, "<b>Last good backup</b>")
		table.insert(lines, row("  Files", commas(data.ok_files)))
		table.insert(lines, row("  Size", common.escape((data.ok_original or "?") .. " → " .. (data.ok_compressed or "?") .. " compressed")))
		table.insert(lines, row("  New data", common.escape((data.ok_deduplicated or "?") .. " (deduplicated)")))
		table.insert(lines, row("  Repository", common.escape(data.ok_repo_size or "?")))
		table.insert(lines, row("  Took", common.escape(data.ok_duration or "?")))
	end

	table.insert(lines, "")
	table.insert(lines, "<b>Recent runs</b>")
	for _, run in ipairs(common.list(data.run)) do
		local start, result, finish = run:match("([^|]*)|([^|]*)|([^|]*)")
		local mark = ({ ok = common.span("ok", "✓"), failed = common.span("bad", "✗") })[result]
			or common.span("accent", "…")
		table.insert(lines, string.format("  %s %s  %s", mark, short(start), duration(start, finish)))
	end

	table.insert(lines, "")
	table.insert(lines, "<b>Postgres dump</b> (monthly)")
	if data.pg_file then
		local age = os.time() - common.time(data.pg_date)
		local lvl = age > PG_STALE_AFTER and "warn" or nil
		table.insert(lines, row("  Newest", common.escape(data.pg_file) .. "  " .. data.pg_size))
		table.insert(lines, row("  Made", common.span(lvl, short(data.pg_date) .. " (" .. common.ago(age) .. " ago)")))
		table.insert(lines, row("  Dumps kept", data.pg_count))
	else
		table.insert(lines, common.span("warn", "  no dumps in ~/database"))
	end
	return table.concat(lines, "\n")
end

local function update(new)
	data = new
	item:update(GLYPH, nil, status())
	item:refresh_popup()
end

common.attach_popup(item, build)

item:buttons(gears.table.join(item:buttons(), awful.button({}, 3, function()
	common.menu({
		{
			"Run backup now",
			function()
				awful.spawn.easy_async({ "systemctl", "--user", "start", "--no-block", "borg-backup.service" }, function()
					refresh()
				end)
			end,
		},
		{
			"Open log",
			function()
				awful.spawn({ settings.terminal, "-e", "less", "+G", LOG })
			end,
		},
		{
			"Open status report",
			function()
				awful.spawn({ "xdg-open", os.getenv("HOME") .. "/reports/status.html" })
			end,
		},
		{
			"Refresh",
			function()
				refresh()
			end,
		},
	})
end)))

-- every 5 minutes; every 20 s while a backup runs, to catch the end quickly
refresh = common.watch("backup-status.sh", 300, update)
-- refresh as soon as a run starts or ends, not just every 5 minutes
common.watch_units({ "borg-backup.service" }, function()
	refresh()
end)
local fast = gears.timer({
	timeout = 20,
	autostart = true,
	callback = function()
		if data.running == "activating" or data.last_result == "running" then
			refresh()
		end
	end,
})

backup.widget = item
backup.refresh = refresh
backup.timer = fast

return backup
