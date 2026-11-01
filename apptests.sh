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
echo "=== TESTS PASS ==="
