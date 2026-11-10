#!/bin/sh
# Prints the backup status as key=value lines, for widgets/backup.lua and for
# reading by hand. Reads only the borg log and file metadata: it never runs
# borg, so it never needs the passphrase.
#
#   last_*      the newest run (result: ok, failed or running)
#   ok_*        the newest successful run, with its --stats numbers
#   run=        one line per recent run: start|result|end
#   pg_*        the newest pg_dumpall file in ~/database

LOG="$HOME/.local/share/borg/backup.log"
DUMPS="$HOME/database"
HISTORY=14

if [ ! -r "$LOG" ]; then
    echo "error=no log at $LOG"
else
    tail -n 50000 "$LOG" | awk -v history="$HISTORY" '
    function err_candidate(line) {
        return line !~ /^(Creating archive|[AMUEdhxics-] \/|-+$|Traceback|  |Repository:|Archive |Time |Duration|Number of|Utilization|This archive|All archives|Chunk index|Deleted data| +(Original|Unique)|---- |$)/
    }
    /^==== BORG RUN START / {
        n++; start[n] = $5 " " $6; result[n] = "running"; finish[n] = ""; err[n] = ""; stats = 1
        next
    }
    n == 0 { next }
    /^==== BORG RUN OK / { result[n] = "ok"; finish[n] = $5 " " $6; next }
    /^==== BORG RUN FAILED / {
        result[n] = "failed"; finish[n] = $7 " " $8
        code[n] = $6; sub(/\)/, "", code[n])
        next
    }
    /^---- prune ----/ { stats = 0 }
    stats && /^Duration: / { sub(/^Duration: /, ""); dur[n] = $0 }
    stats && /^Number of files: / { files[n] = $4 }
    stats && /^This archive: / { orig[n] = $3 " " $4; comp[n] = $5 " " $6; dedup[n] = $7 " " $8 }
    /^All archives: / { repo[n] = $7 " " $8 }
    err[n] == "" && err_candidate($0) { err[n] = substr($0, 1, 200) }
    END {
        if (n == 0) { print "error=no runs in log"; exit }
        print "last_start=" start[n]
        print "last_result=" result[n]
        print "last_end=" finish[n]
        if (result[n] == "failed") { print "last_exit=" code[n]; print "last_error=" err[n] }

        for (i = n; i > 0 && result[i] != "ok"; i--) if (result[i] == "failed") fails++
        print "fails_since_ok=" fails + 0
        if (i > 0) {
            print "ok_start=" start[i]
            print "ok_end=" finish[i]
            print "ok_duration=" dur[i]
            print "ok_files=" files[i]
            print "ok_original=" orig[i]
            print "ok_compressed=" comp[i]
            print "ok_deduplicated=" dedup[i]
            print "ok_repo_size=" repo[i]
        }

        for (i = n; i > 0 && i > n - history; i--) print "run=" start[i] "|" result[i] "|" finish[i]
    }'
fi

echo "running=$(systemctl --user is-active borg-backup.service 2>/dev/null)"
echo "next=$(systemctl --user show borg-backup.timer -p NextElapseUSecRealtime --value 2>/dev/null)"

newest=$(ls -t "$DUMPS"/full-backup_*.sql 2>/dev/null | head -n 1)
if [ -n "$newest" ]; then
    echo "pg_file=$(basename "$newest")"
    echo "pg_date=$(date -r "$newest" '+%F %T')"
    echo "pg_size=$(du -h "$newest" | cut -f1)"
    echo "pg_count=$(ls "$DUMPS"/full-backup_*.sql | wc -l)"
fi
