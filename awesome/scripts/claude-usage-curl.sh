#!/bin/sh
# curl for the Claude usage widget (widgets/claude.lua sets it as curl_cmd).
# The plugin fetches the usage endpoint 5 s after every awesome start and keeps
# its 429 backoff only in memory, so a run of Mod+Ctrl+r (or a Xephyr test
# desktop) means a run of API calls, and the endpoint answers 429. This keeps
# the last good answer on disk and shares it between all of those:
#   - an answer younger than FRESH seconds is reused, without a network call
#   - after a 429, no call for LIMIT_WAIT seconds; the last answer (if not too
#     old) is reused meanwhile, else the plugin gets the 429 and backs off
#   - otherwise the real curl runs with the plugin's arguments, unchanged
# The token never passes through here: the plugin hands curl a header file.
# Output is what the plugin expects: the body, a newline, the HTTP status

# always the real cache, also from a Xephyr test (it sets its own XDG_CACHE_HOME)
DIR="$HOME/.cache/awesome/claude-usage"
FRESH=240
LIMIT_WAIT=300
REUSE_MAX=1800 # never pass off an answer older than this as current

umask 077
mkdir -p "$DIR" && chmod 700 "$DIR"

age() {
    if [ -f "$1" ]; then
        echo $(($(date +%s) - $(stat -c %Y "$1")))
    else
        echo 999999
    fi
}

# one fetch at a time, so two awesome instances starting together share it
exec 9>"$DIR/lock"
flock -w 30 9

if [ "$(age "$DIR/last")" -lt "$FRESH" ]; then
    cat "$DIR/last"
    exit 0
fi

if [ "$(age "$DIR/limited")" -lt "$LIMIT_WAIT" ]; then
    if [ "$(age "$DIR/last")" -lt "$REUSE_MAX" ]; then
        cat "$DIR/last"
    else
        printf '\n429'
    fi
    exit 0
fi

out=$(curl "$@")
code=$?
printf '%s' "$out"
[ "$code" -ne 0 ] && exit "$code"

case "$out" in
*"
200")
    printf '%s' "$out" >"$DIR/last.tmp" && mv "$DIR/last.tmp" "$DIR/last"
    rm -f "$DIR/limited"
    ;;
*"
429")
    : >"$DIR/limited"
    ;;
esac
exit 0
