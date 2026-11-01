#!/usr/bin/env bash
# Проверка загрузки конфига: поднимает Xvfb (виртуальный экран) и
# запускает в нём настоящий qs на репозиторном конфиге. Конфиг либо
# грузится целиком и шелл живёт до таймаута, либо quickshell печатает
# свои реальные ошибки ("X is not a type" и т.п.), которые qmllint
# пропускает.
#
# Сессию не трогает: окна живут в виртуальном фреймбуфере Xvfb,
# окружение очищено (нет DBus, Wayland, Hyprland), рендер софтверный.
set -u
cd "$(dirname "$0")"

out=$(env -i HOME="$HOME" PATH=/usr/bin:/bin \
    QT_QPA_PLATFORM=xcb QT_QUICK_BACKEND=software \
    LIBGL_ALWAYS_SOFTWARE=1 \
    xvfb-run -a -s "-screen 0 1920x1080x24" \
    timeout 12 /usr/bin/qs -p "$(pwd)/QS" 2>&1)
rc=$?

echo "$out" | grep -aE "ERROR|FATAL" | head -30

if [ "$rc" -eq 124 ]; then
    if echo "$out" | grep -qaE "Failed to load configuration"; then
        echo "=== LOAD FAIL: конфиг не загрузился ==="
        exit 1
    fi
    echo "=== LOAD OK: конфиг загрузился, шелл живёт (убит по таймауту) ==="
    exit 0
fi

echo "=== LOAD FAIL: qs завершился сам (rc=$rc) ==="
exit 1
