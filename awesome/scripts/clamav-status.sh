#!/bin/sh
# Prints the ClamAV status as key=value lines, for widgets/clamav.lua and for
# reading by hand. Reads the scan logs written by ~/.local/bin/clamav-*-scan.sh,
# the quarantine folder, the signature database and the clamd service.
#
#   <job>_start/_end/_exit/_running   the newest run of quick, full-home, mnt
#   <job>_infected/_errors/_time      that run's scan summary
#   <job>_note                        a run that scanned nothing, and why
#   <job>_next                        the next scheduled run

STATE="$HOME/.local/share/clamav"
QUARANTINE="$HOME/Quarantine"

for job in quick full-home mnt; do
    log="$STATE/$job.log"
    key=$(echo "$job" | tr - _)
    echo "${key}_next=$(systemctl --user show "clamav-$job-scan.timer" -p NextElapseUSecRealtime --value 2>/dev/null)"
    [ -r "$log" ] || continue

    # the markers written by the scan scripts' log(): "<date> <time> === ... ==="
    start=$(grep -nE '^[0-9-]+ [0-9:]+ === .*starting' "$log" | tail -n 1)
    finish=$(grep -nE '^[0-9-]+ [0-9:]+ === .*(finished|nothing to do|no new/changed)' "$log" | tail -n 1)
    start_line=${start%%:*}
    finish_line=${finish%%:*}

    if [ -n "$finish" ] && [ "${finish_line:-0}" -gt "${start_line:-0}" ]; then
        finish=${finish#*:}
        echo "${key}_end=$(echo "$finish" | cut -c1-19)"
        case $finish in
        *"exit "*) echo "${key}_exit=$(echo "$finish" | sed -E 's/.*exit ([0-9]+).*/\1/')" ;;
        *) echo "${key}_note=$(echo "$finish" | sed -E 's/^[0-9-]+ [0-9:]+ === (.*) ===$/\1/')" ;;
        esac
        running=0
    else
        running=1
    fi
    echo "${key}_running=$running"

    if [ -n "$start" ]; then
        echo "${key}_start=$(echo "${start#*:}" | cut -c1-19)"
        # the summary of that run: everything after its start line
        tail -n +"$start_line" "$log" | awk -v k="$key" '
            /^Infected files: / { infected = $3 }
            /^Total errors: / { errors = $3 }
            /^Time: / { sub(/^Time: /, ""); time = $0 }
            END {
                if (infected != "") print k "_infected=" infected
                if (errors != "") print k "_errors=" errors
                if (time != "") print k "_time=" time
            }'
    fi
done

if [ -d "$QUARANTINE" ]; then
    echo "quarantine_count=$(find "$QUARANTINE" -type f | wc -l)"
    find "$QUARANTINE" -type f -printf 'quarantine_file=%P\n' | head -n 5
fi

echo "clamd=$(systemctl is-active clamav-daemon 2>/dev/null)"

for db in /var/lib/clamav/daily.cld /var/lib/clamav/daily.cvd; do
    [ -r "$db" ] || continue
    info=$(sigtool --info "$db" 2>/dev/null)
    built=$(echo "$info" | sed -n 's/^Build time: //p')
    echo "db_version=$(echo "$info" | sed -n 's/^Version: //p')"
    echo "db_built=$built"
    echo "db_built_epoch=$(date -d "$built" +%s 2>/dev/null)"
    break
done

freshclam=/var/log/clamav/freshclam.log
if [ -r "$freshclam" ]; then
    echo "db_checked=$(grep -E 'update process started' "$freshclam" | tail -n 1 | cut -c1-24)"
    outdated=$(tail -n 50 "$freshclam" | grep -oE 'Recommended version: [0-9.]+' | tail -n 1)
    [ -n "$outdated" ] && echo "clamav_update=${outdated#Recommended version: }"
fi
