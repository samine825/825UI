.pragma library

// Чистая логика времени для приложения Часы. Без eval, без
// компонентов — покрывается юнит-тестами (apptests.sh).
//
// Будильник: { hours, minutes, days: [0..6] (0=воскресенье, как
// Date.getDay(); пустой массив — каждый день), enabled, label,
// snoozeUntil: ISO-строка|null, lastFired: ISO-строка|null }

function pad2(n) {
    return (n < 10 ? "0" : "") + n
}

// следующее срабатывание будильника после now; отложенное
// (snoozeUntil) имеет приоритет; возвращает Date или null
function nextOccurrence(now, alarm) {
    if (!alarm || !alarm.enabled)
        return null

    if (alarm.snoozeUntil) {
        const s = new Date(alarm.snoozeUntil)

        if (!isNaN(s.getTime()) && s > now)
            return s
    }

    const days = alarm.days && alarm.days.length ? alarm.days : null

    // перебор недели вперёд: сегодня+1 минута .. +7 дней
    for (var add = 0; add <= 7; add++) {
        const d = new Date(now.getFullYear(), now.getMonth(),
            now.getDate() + add, alarm.hours, alarm.minutes, 0, 0)

        if (d <= now)
            continue

        if (days && days.indexOf(d.getDay()) === -1)
            continue

        return d
    }

    return null
}

// отложить на minutes минут от базовой точки
function snoozeFrom(base, minutes) {
    return new Date(base.getTime() + minutes * 60000)
}

// ключ срабатывания для защиты от повторов после перезапуска
function occurrenceKey(d) {
    return d ? d.getFullYear() + "-" + d.getMonth() + "-"
        + d.getDate() + " " + pad2(d.getHours()) + ":"
        + pad2(d.getMinutes()) : ""
}

// метка времени будильника в строку HH:mm
function formatAlarmTime(alarm) {
    return pad2(alarm.hours) + ":" + pad2(alarm.minutes)
}

// мм:сс из миллисекунд (мм может быть больше 59)
function formatMS(ms) {
    const totalSec = Math.max(0, Math.floor(ms / 1000))

    return pad2(Math.floor(totalSec / 60)) + ":" + pad2(totalSec % 60)
}

// мм:сс:цц из миллисекунд (секундомер)
function formatHMSCC(ms) {
    const totalCs = Math.max(0, Math.floor(ms / 10))
    const cs = totalCs % 100
    const totalSec = Math.floor(totalCs / 100)

    return pad2(Math.floor(totalSec / 60)) + ":" + pad2(totalSec % 60)
        + ":" + pad2(cs)
}

// количество миллисекунд до конца суток для кратких таймеров — не
// нужно; таймер хранит длительность прямо
function dayNamesShort() {
    return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
}

// короткое имя дня по номеру Date.getDay()
function dayName(day) {
    return dayNamesShort()[day % 7]
}

// человекочитаемый список дней: [] → "Every day", иначе Mon, Wed
function daysLabel(days) {
    if (!days || days.length === 0)
        return "Every day"

    if (days.length === 7)
        return "Every day"

    const sorted = days.slice().sort()

    // будни и выходные целиком — особыми словами
    if (sorted.join(",") === "1,2,3,4,5")
        return "Weekdays"

    if (sorted.join(",") === "0,6")
        return "Weekends"

    return sorted.map(dayName).join(", ")
}
