.pragma library

// Калькуляторная логика: токенизатор + сортировочная станция.
// Чистые функции без eval — покрываются юнит-тестами (apptests.sh).
// Поддержка: + − × ÷, скобки, унарный минус, постфиксный процент,
// десятичные дроби. Принимаются и ASCII (*, /, -), и витринные
// символы (×, ÷, −).

function tokenize(expr) {
    var tokens = []
    var i = 0

    while (i < expr.length) {
        var ch = expr[i]

        if (ch === " " || ch === "\t") {
            i++
            continue
        }

        // число: цифры и одна точка
        if (ch >= "0" && ch <= "9" || ch === ".") {
            var num = ""
            var dots = 0

            while (i < expr.length
                   && (expr[i] >= "0" && expr[i] <= "9"
                       || expr[i] === ".")) {
                if (expr[i] === ".") {
                    dots++
                    if (dots > 1)
                        throw new Error("bad number")
                }

                num += expr[i]
                i++
            }

            if (num === "." || num === "")
                throw new Error("bad number")

            tokens.push({ type: "num", value: Number(num) })
            continue
        }

        var op = null

        if (ch === "+" || ch === "-" || ch === "−" || ch === "_")
            op = "+-"
        else if (ch === "×" || ch === "*" || ch === "x" || ch === "X")
            op = "×"
        else if (ch === "÷" || ch === "/")
            op = "÷"
        else if (ch === "%")
            op = "%"
        else if (ch === "(")
            op = "("
        else if (ch === ")")
            op = ")"

        if (op === null)
            throw new Error("bad char: " + ch)

        // у знака +- храним исходный символ: вычитание и сложение
        // разделятся позже, в унарной/бинарной развилке
        tokens.push({ type: "op", op: op, raw: ch })
        i++
    }

    return tokens
}

// приоритеты: add/sub = 1, ×÷ = 2, унарный минус = 3, процент = 4
function precedence(op) {
    if (op === "add" || op === "sub")
        return 1
    if (op === "×" || op === "÷")
        return 2
    if (op === "u-")
        return 3
    if (op === "%")
        return 4
    return 0
}

function isRightAssoc(op) {
    return op === "u-"
}

// определяет, что токен-оператор стоит в унарной позиции
function isUnaryContext(tokens, index) {
    if (index === 0)
        return true

    var prev = tokens[index - 1]

    return prev.type === "op" && prev.op !== ")" && prev.op !== "%"
}

function toRpn(tokens) {
    var out = []
    var stack = []

    for (var i = 0; i < tokens.length; i++) {
        var t = tokens[i]

        if (t.type === "num") {
            out.push(t)
            continue
        }

        if (t.op === "(") {
            stack.push(t)
            continue
        }

        if (t.op === ")") {
            var matched = false

            while (stack.length > 0) {
                var top = stack.pop()

                if (top.op === "(") {
                    matched = true
                    break
                }

                out.push(top)
            }

            if (!matched)
                throw new Error("unbalanced )")

            continue
        }

        var op = t.op

        // развилка знака: в унарной позиции — унарный минус,
        // иначе — сложение или вычитание по исходному символу
        if (op === "+-") {
            if (isUnaryContext(tokens, i))
                op = "u-"
            else
                op = t.raw === "+" ? "add" : "sub"
        }

        while (stack.length > 0) {
            var stop = stack[stack.length - 1]

            if (stop.op === "(")
                break

            var sp = precedence(stop.op)
            var tp = precedence(op)

            if (sp > tp || (sp === tp && !isRightAssoc(op)))
                out.push(stack.pop())
            else
                break
        }

        stack.push({ type: "op", op: op })
    }

    while (stack.length > 0) {
        var rest = stack.pop()

        if (rest.op === "(")
            throw new Error("unbalanced (")

        out.push(rest)
    }

    return out
}

function evalRpn(rpn) {
    var st = []

    for (var i = 0; i < rpn.length; i++) {
        var t = rpn[i]

        if (t.type === "num") {
            st.push(t.value)
            continue
        }

        if (t.op === "u-") {
            if (st.length < 1)
                throw new Error("operand missing")

            st.push(-st.pop())
            continue
        }

        if (t.op === "%") {
            if (st.length < 1)
                throw new Error("operand missing")

            st.push(st.pop() / 100)
            continue
        }

        if (st.length < 2)
            throw new Error("operand missing")

        var b = st.pop()
        var a = st.pop()

        if (t.op === "add")
            st.push(a + b)
        else if (t.op === "sub")
            st.push(a - b)
        else if (t.op === "×")
            st.push(a * b)
        else if (t.op === "÷") {
            if (b === 0)
                throw new Error("division by zero")

            st.push(a / b)
        } else
            throw new Error("unknown op")
    }

    if (st.length !== 1)
        throw new Error("malformed expression")

    return st[0]
}

// вычислить выражение; бросает Error с понятной причиной
function evaluate(expr) {
    if (typeof expr !== "string" || expr.trim() === "")
        throw new Error("empty")

    return evalRpn(toRpn(tokenize(expr)))
}

// безопасный вариант: число или null (для живого предпросчёта)
function evaluateOrNull(expr) {
    try {
        var v = evaluate(expr)

        if (typeof v !== "number" || isNaN(v) || !isFinite(v))
            return null

        return v
    } catch (e) {
        return null
    }
}

// формат результата: до 10 значащих цифр, без хвостовых нулей
function format(value) {
    if (value === null || value === undefined
        || typeof value !== "number" || isNaN(value) || !isFinite(value))
        return ""

    return String(Number(value.toPrecision(10)))
}
