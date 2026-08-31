#!/bin/bash
OUT="/data/data/com.termux/home/apps.json"
echo '[' > "$OUT"
first=true
for f in $(find /data/data/com.termux/files/usr/share/applications -name '*.desktop' 2>/dev/null | head -400); do
    name=$(grep -m1 '^Name=' "$f" 2>/dev/null | cut -d= -f2)
    icon=$(grep -m1 '^Icon=' "$f" 2>/dev/null | cut -d= -f2)
    exec=$(grep -m1 '^Exec=' "$f" 2>/dev/null | cut -d= -f2 | sed 's/%[fFuDdUutTv]//g')
    if [ -n "$name" ]; then
        [ "$first" = false ] && echo ',' >> "$OUT"
        first=false
        ne=$(printf '%s' "$name" | sed 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g')
        ie=$(printf '%s' "$icon" | sed 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g')
        ee=$(printf '%s' "$exec" | sed 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g')
        printf '  {"name":"%s","icon":"%s","exec":"%s"}' "$ne" "$ie" "$ee" >> "$OUT"
    fi
done
echo '' >> "$OUT"
echo ']' >> "$OUT"
