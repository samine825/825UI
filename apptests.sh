#!/usr/bin/env bash
# Юнит-тесты чистой логики приложений (Calc.js, TimeMath.js, ...).
# Пробник — временный shell.qml в корне репо (как visualtest.sh),
# в Xvfb с песочным HOME; модули печатают строки TEST_OK/TEST_FAIL,
# скрипт считает провалы.
set -u
cd "$(dirname "$0")"

probe=shell.qml
if [ -e "$probe" ]; then
    echo "=== $probe уже существует — не трогаю ===" >&2
    exit 1
fi

cat > "$probe" <<'EOF'
import QtQuick
import Quickshell
import "QS/Apps/Calc.js" as Calc
import "QS/Apps/EmojiData.js" as EmojiData
import "QS/Apps/TimeMath.js" as TimeMath

ShellRoot {
    Item {
        Component.onCompleted: {
            let fails = 0
            let total = 0

            function ok(name, cond) {
                total++
                if (cond)
                    console.log("TEST_OK " + name)
                else {
                    fails++
                    console.log("TEST_FAIL " + name)
                }
            }

            function eq(name, actual, expected) {
                const good = actual === expected
                ok(name + " [" + actual + " === " + expected + "]", good)
            }

            function near(name, actual, expected) {
                const good = Math.abs(actual - expected) < 1e-9
                ok(name + " [" + actual + " ~ " + expected + "]", good)
            }

            function throws(name, fn) {
                try {
                    fn()
                    ok(name + " [no throw]", false)
                } catch (e) {
                    ok(name + " [throws: " + e.message + "]", true)
                }
            }

            // === Calc.js: арифметика ===
            near("add", Calc.evaluate("1+2"), 3)
            near("precedence", Calc.evaluate("2+3×4"), 14)
            near("parens", Calc.evaluate("(2+3)×4"), 20)
            near("div", Calc.evaluate("10÷4"), 2.5)
            near("unary", Calc.evaluate("−5+3"), -2)
            near("unary after op", Calc.evaluate("2×−3"), -6)
            near("double unary", Calc.evaluate("5−−3"), 8)
            near("percent", Calc.evaluate("50%"), 0.5)
            near("percent mul", Calc.evaluate("200×10%"), 20)
            near("decimals", Calc.evaluate("1.5+.5"), 2)
            near("nested parens", Calc.evaluate("((2))"), 2)
            near("float sum", Calc.evaluate("0.1+0.2"), 0.3)
            near("ascii ops", Calc.evaluate("2*3/6"), 1)
            near("percent of", Calc.evaluate("90+10%"), 90.1)

            // === Calc.js: ошибки ===
            throws("div zero", () => Calc.evaluate("10÷0"))
            throws("dangling op", () => Calc.evaluate("2+"))
            throws("bad order", () => Calc.evaluate("×2"))
            throws("unbalanced )", () => Calc.evaluate("2)"))
            throws("unbalanced (", () => Calc.evaluate("(2+3"))
            throws("double dot", () => Calc.evaluate("2..3"))
            throws("bad char", () => Calc.evaluate("abc"))
            throws("lone dot", () => Calc.evaluate("."))
            throws("empty", () => Calc.evaluate(""))
            throws("bare op pair", () => Calc.evaluate("+×2"))

            // === Calc.js: evaluateOrNull ===
            ok("ornull ok", Calc.evaluateOrNull("2+2") === 4)
            ok("ornull error", Calc.evaluateOrNull("2+") === null)
            ok("ornull empty", Calc.evaluateOrNull("") === null)

            // === Calc.js: format ===
            eq("format float", Calc.format(0.1 + 0.2), "0.3")
            eq("format int", Calc.format(42), "42")
            eq("format trailing", Calc.format(1.50), "1.5")
            eq("format big", Calc.format(1e21), "1e+21")
            eq("format neg", Calc.format(-7), "-7")
            eq("format null", Calc.format(null), "")

            // === EmojiData: поиск ===
            ok("search dog", EmojiData.search("dog", "").length > 0)
            ok("search cat", EmojiData.search("cat", "animals")
                .some(e => e.ch === "🐱"))
            eq("search empty", EmojiData.search("zzzznope", "").length, 0)
            ok("search by kw", EmojiData.search("thumbs up", "")
                .some(e => e.ch === "👍"))
            eq("byCategory smileys", EmojiData.byCategory("smileys")
                .every(e => e.cat === "smileys") ? 1 : 0, 1)
            eq("nameOf", EmojiData.nameOf("😀"), "grinning face")
            eq("nameOf unknown", EmojiData.nameOf("🜛"), "")
            ok("categories 9", EmojiData.categories.length === 9)

            // === TimeMath: следующее срабатывание ===
            // среда 2026-03-04 10:00:00 UTC-локаль — берём
            // конструктор с компонентами, локаль не важна
            const now = new Date(2026, 2, 4, 10, 0, 0, 0)

            eq("next today later",
                TimeMath.nextOccurrence(now,
                    { enabled: true, hours: 15, minutes: 30 })
                    .getDate(), 4)
            eq("next tomorrow",
                TimeMath.nextOccurrence(now,
                    { enabled: true, hours: 9, minutes: 0 })
                    .getDate(), 5)
            eq("disabled null",
                TimeMath.nextOccurrence(now,
                    { enabled: false, hours: 23, minutes: 0 }), null)
            eq("days filter",
                TimeMath.nextOccurrence(now,
                    { enabled: true, hours: 11, minutes: 0,
                        days: [4] }).getDate(), 5)
            eq("days today ok",
                TimeMath.nextOccurrence(now,
                    { enabled: true, hours: 11, minutes: 0,
                        days: [3] }).getDate(), 4)
            eq("empty days every day",
                TimeMath.nextOccurrence(now,
                    { enabled: true, hours: 11, minutes: 0,
                        days: [] }).getDate(), 4)

            // snooze в будущем приоритетнее обычного времени
            const snz = new Date(2026, 2, 4, 12, 0, 0, 0)

            eq("snooze priority",
                TimeMath.nextOccurrence(now, {
                    enabled: true, hours: 23, minutes: 0,
                    snoozeUntil: snz.toISOString()
                }).getHours(), 12)
            eq("snooze past ignored",
                TimeMath.nextOccurrence(now, {
                    enabled: true, hours: 9, minutes: 0,
                    snoozeUntil: new Date(2026, 2, 3, 12, 0)
                        .toISOString()
                }).getDate(), 5)

            // неделя вперёд: воскресный будильник из среды
            eq("week wrap",
                TimeMath.nextOccurrence(now, {
                    enabled: true, hours: 8, minutes: 0,
                    days: [0] }).getDate(), 8)

            // === TimeMath: форматирование ===
            eq("formatMS", TimeMath.formatMS(65 * 1000), "01:05")
            eq("formatMS big", TimeMath.formatMS(90 * 60000), "90:00")
            eq("formatMS zero", TimeMath.formatMS(0), "00:00")
            eq("formatHMSCC", TimeMath.formatHMSCC(12034), "00:12:03")
            eq("formatHMSCC min", TimeMath.formatHMSCC(61234),
                "01:01:23")
            eq("pad2", TimeMath.pad2(7), "07")
            eq("daysLabel empty", TimeMath.daysLabel([]), "Every day")
            eq("daysLabel weekdays",
                TimeMath.daysLabel([1, 2, 3, 4, 5]), "Weekdays")
            eq("daysLabel weekend",
                TimeMath.daysLabel([6, 0]), "Weekends")
            eq("daysLabel mix", TimeMath.daysLabel([1, 3]),
                "Mon, Wed")
            eq("snoozeFrom",
                TimeMath.snoozeFrom(new Date(2026, 2, 4, 10, 0), 5)
                    .getMinutes(), 5)
            eq("occurrenceKey",
                TimeMath.occurrenceKey(new Date(2026, 2, 4, 7, 5)),
                "2026-2-4 07:05")

            console.log("TEST_TOTAL " + total + " FAILS " + fails)
            Qt.quit()
        }
    }
}
EOF
trap 'rm -f "$probe"' EXIT

out=$(env -i HOME="$HOME" PATH=/usr/bin:/bin \
    QT_QPA_PLATFORM=xcb QT_QUICK_BACKEND=software \
    LIBGL_ALWAYS_SOFTWARE=1 \
    xvfb-run -a -s "-screen 0 800x600x24" \
    timeout 20 /usr/bin/qs -p "$(pwd)" 2>&1)
rc=$?

echo "$out" | grep -aE "TEST_OK|TEST_FAIL|TEST_TOTAL|ERROR|FATAL" | head -60

fails=$(echo "$out" | grep -ac "TEST_FAIL" || true)
if [ "$fails" -gt 0 ] || echo "$out" | grep -qaE "ERROR|FATAL"; then
    echo "=== TESTS FAIL ==="
    exit 1
fi
if ! echo "$out" | grep -qa "TEST_TOTAL"; then
    echo "=== TESTS DID NOT RUN ==="
    exit 1
fi

# === фаза 2: недавние эмодзи, персист состояния ===
mkdir -p /tmp/825testhome/.825UI/state
rm -f /tmp/825testhome/.825UI/state/emoji.json

cat > "$probe" <<'EOF'
import QtQuick
import Quickshell
import "QS/Apps"

ShellRoot {
    EmojiPickerContent {
        id: app
        x: 0; y: 0
        stateFile: "/tmp/825testhome/.825UI/state/emoji.json"
    }

    Timer { id: t1; interval: 1200; running: true
        onTriggered: { app.pick("😀"); t2.start() } }
    Timer { id: t2; interval: 400
        onTriggered: { app.pick("😂"); t3.start() } }
    Timer { id: t3; interval: 400
        onTriggered: { app.pick("👍"); t4.start() } }
    // повторный выбор существующего — поднимается наверх без дубля
    Timer { id: t4; interval: 400
        onTriggered: { app.pick("😀"); t5.start() } }
    // файл асинхронный — даём дописать, затем проверяем перезагрузкой
    Timer { id: t5; interval: 1200
        onTriggered: {
            if (app.recentList.length !== 3
                    || app.recentList[0] !== "😀"
                    || app.recentList[1] !== "👍"
                    || app.recentList[2] !== "😂") {
                console.log("TEST2_FAIL recent order "
                    + JSON.stringify(app.recentList))
                Qt.quit()
                return
            }
            console.log("TEST2_OK recent order")
            app.destroy()
            loader.active = true
        } }

    Loader {
        id: loader
        active: false
        sourceComponent: EmojiPickerContent {
            stateFile: "/tmp/825testhome/.825UI/state/emoji.json"
            onRecentListChanged: {
                if (recentList.length === 3
                        && recentList[0] === "😀") {
                    console.log("TEST2_OK reload persist")
                    Qt.quit()
                }
            }
        }
    }

    Timer { interval: 8000; running: true
        onTriggered: {
            console.log("TEST2_FAIL timeout")
            Qt.quit()
        } }
}
EOF

out2=$(env -i HOME=/tmp/825testhome PATH=/usr/bin:/bin \
    QT_QPA_PLATFORM=xcb QT_QUICK_BACKEND=software \
    LIBGL_ALWAYS_SOFTWARE=1 \
    xvfb-run -a -s "-screen 0 800x600x24" \
    timeout 20 /usr/bin/qs -p "$(pwd)" 2>&1)

echo "$out2" | grep -aE "TEST2_OK|TEST2_FAIL|ERROR|FATAL" | head -10

if echo "$out2" | grep -qa "TEST2_FAIL" || echo "$out2" | grep -qaE "ERROR|FATAL" \
   || ! echo "$out2" | grep -qa "TEST2_OK reload persist"; then
    echo "=== TESTS FAIL (phase 2) ==="
    exit 1
fi


# === фаза 3: логика буфера (дедуп, лимит, пины, очистка) ===
mkdir -p /tmp/825testhome/.825UI/state/clipboard
rm -f /tmp/825testhome/.825UI/state/clipboard.json

cat > "$probe" <<'EOF'
import QtQuick
import Quickshell
import "QS/Apps"

ShellRoot {
    ClipboardContent {
        id: app
        stateFile: "/tmp/825testhome/.825UI/state/clipboard.json"
        imagesDir: "/tmp/825testhome/.825UI/state/clipboard"
    }

    PanelWindow {
        visible: true
        color: "transparent"
        exclusiveZone: -1
        anchors { top: true; left: true }
        implicitWidth: 10; implicitHeight: 10

        Timer {
            interval: 500; running: true
            onTriggered: {
                var fails = 0

                function ok(name, cond) {
                    if (!cond) {
                        fails++
                        console.warn("TEST3_FAIL " + name)
                    } else {
                        console.warn("TEST3_OK " + name)
                    }
                }

                app.addText("hello")
                app.addText("world")
                ok("two entries", app.entries.length === 2)

                app.addText("hello")
                ok("dedup no dup", app.entries.length === 2)
                ok("dedup moved top",
                    app.entries[0].text === "hello")

                for (var i = 0; i < 110; i++)
                    app.addText("msg " + i)

                ok("cap 100", app.entries.length === 100)

                var pinnedId = app.entries[0].id
                app.togglePin(pinnedId)
                for (var j = 200; j < 260; j++) {
                    app.addText("more " + j)

                }

                ok("pinned survived", app.entries.some(
                    function (e) {
                        return e.id === pinnedId && e.pinned
                    }))
                ok("cap after pin", app.entries.length === 101)

                app.clearUnpinned()
                ok("clear keeps pinned",
                    app.entries.length === 1
                    && app.entries[0].id === pinnedId)

                app.addText("needle in stack")
                app.query = "needle"
                ok("search filters",
                    app.visibleEntries.length === 1)
                app.query = ""

                app.removeEntry(pinnedId)
                ok("remove entry", app.entries.length === 1)

                console.warn("TEST3_TOTAL fails " + fails)
                Qt.quit()
            }
        }
    }
}
EOF

out3=$(env -i HOME=/tmp/825testhome PATH=/usr/bin:/bin \
    QT_QPA_PLATFORM=xcb QT_QUICK_BACKEND=software \
    LIBGL_ALWAYS_SOFTWARE=1 \
    xvfb-run -a -s "-screen 0 800x600x24" \
    timeout 120 /usr/bin/qs -p "$(pwd)" 2>&1)

echo "$out3" | grep -aE "TEST3_OK|TEST3_FAIL|TEST3_TOTAL" | head -15

if echo "$out3" | grep -qa "TEST3_FAIL" || ! echo "$out3" | grep -qa "TEST3_TOTAL"; then
    echo "=== TESTS FAIL (phase 3) ==="
    exit 1
fi

echo "=== TESTS PASS ==="
