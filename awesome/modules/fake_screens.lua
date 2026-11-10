-- Test helper for scripts/test-xephyr.sh: splits Xephyr's single screen into
-- side-by-side fake monitors, from AWESOME_FAKE_SCREENS ("960x600 600x960").
-- Only loaded when that variable is set, so it never runs in a real session
local spec = os.getenv("AWESOME_FAKE_SCREENS")

local sizes = {}
for w, h in spec:gmatch("(%d+)x(%d+)") do
	sizes[#sizes + 1] = { tonumber(w), tonumber(h) }
end

local x = 0
for i, size in ipairs(sizes) do
	if i == 1 then
		screen[1]:fake_resize(0, 0, size[1], size[2])
	else
		screen.fake_add(x, 0, size[1], size[2])
	end
	x = x + size[1]
end
