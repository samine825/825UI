#!/bin/sh
COUNT_FILE="/tmp/quickshell_notify_count"
echo 0 > "$COUNT_FILE"
while true; do
    count=$(makoctl list 2>/dev/null | wc -l)
    echo "$count" > "$COUNT_FILE"
    sleep 1
    # Check if mako is still running
    if ! pgrep -x mako > /dev/null 2>&1; then
        echo 0 > "$COUNT_FILE"
        sleep 5
    fi
done
