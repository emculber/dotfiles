-- Fixes for running awesome 4.3 on newer libraries. Load before anything else.
local lgi = require("lgi")

-- GLib 2.80 moved Gio.UnixInputStream/UnixOutputStream to the GioUnix
-- namespace. awful.spawn (easy_async, with_line_callback, and every widget
-- built on them) still uses the old names and fails with "attempt to index a
-- nil value (field 'UnixInputStream')". Point the old names at the new classes
-- gears.timer:stop() on a timer that isn't running prints a "timer not
-- started" traceback in 4.3. widgets/claude_usage stops its timer before every
-- re-arm, which filled the log; make that case a quiet no-op
local timer = require("gears.timer")
local stop = timer.stop
function timer:stop()
	if self.data.source_id == nil then
		return
	end
	return stop(self)
end

local Gio = lgi.Gio
if not Gio.UnixInputStream then
	local ok, GioUnix = pcall(lgi.require, "GioUnix")
	if ok then
		Gio.UnixInputStream = GioUnix.InputStream
		Gio.UnixOutputStream = GioUnix.OutputStream
	end
end
