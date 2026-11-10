#!/bin/sh
# I2P router status for the bar widget (widgets/i2p.lua), as key=value lines.
# Running or not comes from the wrapper's pid file; the rest from the router
# console's sidebar (http://127.0.0.1:7657/xhr1.jsp, no password needed):
#   running=yes|no  console=up|down  version= uptime=
#   bw3s= bw5m= ("in / out unit")  used= ("in / out")
#   network=OK|Firewalled|...  update=<newer upstream release the router knows of>
#   pkg_installed= pkg_candidate= (apt's versions of the i2p package)
#   tunnels_ready=N tunnels_total=N  tunnel=<name> (one line each)

PIDFILE="$HOME/.i2p/i2p.pid"
CONSOLE="http://127.0.0.1:7657/xhr1.jsp"

# what apt has: installed and candidate (the router itself only knows upstream
# releases, which can be ahead of the PPA). apt-cache is slow, so its answer
# is kept for an hour
echo "pkg_installed=$(dpkg-query -W -f='${Version}' i2p 2>/dev/null)"
apt_cache="${XDG_RUNTIME_DIR:-/tmp}/i2p-apt-candidate"
if [ -z "$(find "$apt_cache" -mmin -60 2>/dev/null)" ]; then
    apt-cache policy i2p 2>/dev/null | sed -n 's/^ *Candidate: *//p' >"$apt_cache"
fi
echo "pkg_candidate=$(cat "$apt_cache" 2>/dev/null)"

pid=$(cat "$PIDFILE" 2>/dev/null)
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    echo "running=yes"
else
    echo "running=no"
    exit 0
fi

html=$(curl -s -m 3 "$CONSOLE")
if [ -z "$html" ]; then
    echo "console=down" # running, but the console isn't up yet (starting)
    exit 0
fi
echo "console=up"

# the sidebar uses &nbsp; and a narrow no-break space (&#8239;) between numbers
# and units; one line per tag makes it easy to pick out
text=$(printf '%s' "$html" | sed -e 's/&nbsp;/ /g' -e 's/&#8239;/ /g' -e 's/></>\n</g')

# value_after LABEL prints the cell after the one holding "<b>LABEL</b>"
value_after() {
    printf '%s\n' "$text" | awk -v label="<b>$1</b>" '
        index($0, label) { found = 1; next }
        found && /<td/ { sub(/<[^>]*>/, ""); sub(/<.*/, ""); print; exit }'
}

echo "version=$(value_after 'Version:')"
echo "uptime=$(value_after 'Uptime:')"

# in / out with their unit, which the console picks by size (KBps, MBps; GB)
echo "bw3s=$(value_after '3 sec:')"
echo "bw5m=$(value_after '5 min:')"
echo "used=$(value_after 'Used:')"

echo "network=$(printf '%s' "$html" | sed -n 's|.*>Network: \([^<]*\)<.*|\1|p' | head -1)"
echo "update=$(printf '%s' "$html" | sed -n 's|.*Update available:<br>Version \([^<]*\)<.*|\1|p' | head -1)"

# local tunnels: names, and how many have the "Ready" status image
tunnels=$(printf '%s' "$html" | sed -n '/id="sb_localtunnels"/,/<\/table>/p')
echo "tunnels_total=$(printf '%s' "$tunnels" | grep -o 'title="Show tunnels">[^<]*' | wc -l)"
echo "tunnels_ready=$(printf '%s' "$tunnels" | grep -o 'alt="Ready"' | wc -l)"
printf '%s' "$tunnels" | grep -o 'title="Show tunnels">[^<]*' | sed 's|.*>|tunnel=|'
