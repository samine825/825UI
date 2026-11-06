#!/usr/bin/env python3
# Единоразовый парсер полного списка эмодзи unicode.org в локальный
# файл данных. Запуск вручную при обновлении стандарта:
#   Tools/emoji_parse.py > QS/Apps/EmojiData.js
# (скачивает full-emoji-list.html, вытаскивает группы, символы,
# CLDR-имена и ключевые слова, пишет pragma library для QML)
import html
import re
import sys
import urllib.request

URL = "https://unicode.org/emoji/charts/full-emoji-list.html"

# подписи групп на таб-баре
GROUP_LABELS = {
    "Smileys & Emotion": "Smileys",
    "People & Body": "People",
    "Animals & Nature": "Animals",
    "Food & Drink": "Food",
    "Activities": "Activity",
    "Travel & Places": "Travel",
    "Objects": "Objects",
    "Symbols": "Symbols",
    "Flags": "Flags",
}

TD = re.compile(r"<td class='([^']*)'[^>]*>(.*?)</td>", re.S)
TH = re.compile(r"<th[^>]*>(.*?)</th>", re.S)
TAGS = re.compile(r"<[^>]+>")


def strip(fragment):
    return html.unescape(TAGS.sub("", fragment)).strip()


def js_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    raw = urllib.request.urlopen(URL, timeout=120).read().decode("utf-8")

    groups = []          # порядок групп
    subgroup = ""
    group = ""
    entries = []

    for row in re.split(r"<tr[^>]*>", raw):
        head = TH.search(row)
        if head:
            text = strip(head.group(1))
            if 'class="bighead"' in row or "bighead" in head.group(0):
                group = text
                if group not in groups and group in GROUP_LABELS:
                    groups.append(group)
                subgroup = ""
            elif "mediumhead" in row:
                subgroup = text
            continue

        tds = TD.findall(row)
        if len(tds) < 4 or "class='code'" not in row:
            continue

        # td chars — символ; td name — CLDR short name. Ключевых
        # слов в чарте больше нет — поиск идёт по имени и подгруппе
        chars = [strip(body) for cls, body in tds if cls == "chars"]
        names = [strip(body) for cls, body in tds if cls == "name"]

        if not chars or not names or not chars[0]:
            continue

        ch = chars[0]
        name = names[0]
        kw = subgroup

        if group not in GROUP_LABELS:
            continue

        entries.append({
            "ch": ch,
            "name": name,
            "kw": kw,
            "group": group,
            "subgroup": subgroup,
        })

    if not entries:
        sys.exit("не распарсилось ни одного эмодзи")

    out = []
    out.append(".pragma library")
    out.append("")
    out.append("// СГЕНЕРИРОВАНО Tools/emoji_parse.py из")
    out.append("// https://unicode.org/emoji/charts/full-emoji-list.html")
    out.append("// Не править руками — перегенерировать скриптом.")
    out.append("")
    out.append("var categories = [")
    out.append('    { id: "frequent", label: "Recent" },')
    for g in groups:
        out.append("    { id: %s, label: %s }," % (
            js_string(g), js_string(GROUP_LABELS[g])))
    out.append("]")
    out.append("")
    out.append("// { ch, name, kw, group, subgroup } — %d шт." % len(entries))
    out.append("var entries = [")
    for e in entries:
        out.append("    { ch: %s, name: %s, kw: %s, group: %s, subgroup: %s }," % (
            js_string(e["ch"]), js_string(e["name"]),
            js_string(e["kw"]), js_string(e["group"]),
            js_string(e["subgroup"])))
    out.append("]")
    out.append("")
    out.append("var _byChar = null")
    out.append("")
    out.append("function _index() {")
    out.append("    if (_byChar)")
    out.append("        return _byChar")
    out.append("")
    out.append("    _byChar = {}")
    out.append("    for (var i = 0; i < entries.length; i++)")
    out.append("        _byChar[entries[i].ch] = entries[i]")
    out.append("")
    out.append("    return _byChar")
    out.append("}")
    out.append("")
    out.append("// поиск по имени и ключевым словам внутри группы")
    out.append("// (пустая строка — вся группа)")
    out.append("function search(query, group) {")
    out.append("    const q = query.trim().toLowerCase()")
    out.append("    const res = []")
    out.append("")
    out.append("    for (let i = 0; i < entries.length; i++) {")
    out.append("        const e = entries[i]")
    out.append("")
    out.append("        if (group && e.group !== group)")
    out.append("            continue")
    out.append("        if (q === \"\") {")
    out.append("            res.push(e)")
    out.append("            continue")
    out.append("        }")
    out.append("        if (e.name.toLowerCase().indexOf(q) !== -1")
    out.append("                || e.kw.toLowerCase().indexOf(q) !== -1)")
    out.append("            res.push(e)")
    out.append("    }")
    out.append("")
    out.append("    return res")
    out.append("}")
    out.append("")
    out.append("function infoOf(ch) {")
    out.append("    return _index()[ch]")
    out.append("}")
    out.append("")
    out.append("function nameOf(ch) {")
    out.append("    const e = _index()[ch]")
    out.append("")
    out.append("    return e ? e.name : \"\"")
    out.append("}")
    out.append("")

    print("\n".join(out))
    sys.stderr.write("эмодзи: %d, групп: %d\n"
        % (len(entries), len(groups)))


if __name__ == "__main__":
    main()
