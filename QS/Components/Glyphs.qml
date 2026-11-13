pragma Singleton

import QtQuick
import Quickshell

// Каталог глифов иконок: координатное поле 24x24, рисуются VIcon.
// Все глифы — штриховые, рассчитаны на толщину 2 единицы глифа
// (VIcon по умолчанию): вес иконки одинаков в любом месте и любом
// размере. Никаких заливных глифов — они выпадали из линейной
// системы и выглядели иначе, чем штриховые.
Singleton {
    id: glyphs

    readonly property string iconVolumeBody:
        "M 4.5,9.5 L 8.5,9.5 L 13.5,5 L 13.5,19 L 8.5,14.5 L 4.5,14.5 Z"
    readonly property string iconVolumeWaves:
        "M 15.5,9.5 C 17,10.8 17,13.2 15.5,14.5 M 18.1,7 C 20.8,9.6 20.8,14.4 18.1,17"
    readonly property string iconVolumeMuted:
        "M 15.5,9.5 L 20.5,14.5 M 20.5,9.5 L 15.5,14.5"
    readonly property string iconBrightness:
        "M 12,7.6 A 4.4,4.4 0 1,0 12,16.4 A 4.4,4.4 0 1,0 12,7.6 Z"
        + " M 12,1.8 L 12,4.4 M 12,19.6 L 12,22.2 M 1.8,12 L 4.4,12 M 19.6,12 L 22.2,12"
        + " M 4.6,4.6 L 6.5,6.5 M 17.5,17.5 L 19.4,19.4 M 4.6,19.4 L 6.5,17.5 M 17.5,6.5 L 19.4,4.6"
    readonly property string iconNote:
        "M 6,18.6 A 2.6,2.6 0 1,0 11.2,18.6 A 2.6,2.6 0 1,0 6,18.6 Z"
        + " M 11.2,18.6 L 11.2,5.2 L 19.5,3.5 L 19.5,7.6 L 11.2,9.3 Z"
    readonly property string iconPlay: "M 8.5,5.5 L 18,12 L 8.5,18.5 Z"
    readonly property string iconPause:
        "M 7.5,5.5 L 10.5,5.5 L 10.5,18.5 L 7.5,18.5 Z"
        + " M 13.5,5.5 L 16.5,5.5 L 16.5,18.5 L 13.5,18.5 Z"
    readonly property string iconPrev:
        "M 18.5,5.5 L 18.5,18.5 L 8.5,12 Z M 6,5.5 L 6,18.5"
    readonly property string iconNext:
        "M 5.5,5.5 L 5.5,18.5 L 15.5,12 Z M 18,5.5 L 18,18.5"
    readonly property string iconPowerStroke:
        "M 18.36,6.64 A 9,9 0 1,1 5.64,6.64 M 12,2 L 12,10"
    readonly property string iconRebootStroke:
        "M 22.4,4.6 L 22.4,10 L 17,10 M 20.1,14.6 A 8.4,8.4 0 1,1 18.1,6.1 L 22.4,10"
    readonly property string iconMoon:
        "M 20.5,13 A 9,9 0 1,1 11,3.5 A 7.2,7.2 0 0,0 20.5,13 Z"
    readonly property string iconHibernateStroke:
        "M 4,5 L 11.5,5 L 4,13 L 11.5,13 M 14,12 L 19.5,12 L 14,18.5 L 19.5,18.5"
    readonly property string iconLock:
        "M 5.5,10.5 L 18.5,10.5 L 18.5,20.5 L 5.5,20.5 Z"
        + " M 8.5,10.5 L 8.5,7.5 A 3.5,3.5 0 0,1 15.5,7.5 L 15.5,10.5"
    readonly property string iconMic:
        "M 12,2 A 3,3 0 0,1 15,5 L 15,11 A 3,3 0 0,1 12,14 A 3,3 0 0,1 9,11 L 9,5 A 3,3 0 0,1 12,2 Z"
        + " M 5,11 A 7,7 0 0,0 19,11 M 12,18 L 12,21.5"
    readonly property string iconMicMuted: glyphs.iconMic + " M 4,4 L 20,20"
    readonly property string iconWifi:
        "M 2.4,9.6 C 6.8,5.2 17.2,5.2 21.6,9.6"
        + " M 5.6,13.2 C 9,9.9 15,9.9 18.4,13.2"
        + " M 8.9,16.7 C 10.7,15.1 13.3,15.1 15.1,16.7"
    readonly property string iconWifiDot:
        "M 10.7,19.4 A 1.3,1.3 0 1,0 13.3,19.4 A 1.3,1.3 0 1,0 10.7,19.4 Z"
    readonly property string iconBluetooth:
        "M 7,7.5 L 17,16.5 L 12,21 L 12,3 L 17,7.5 L 7,16.5"

    // === приложения ===

    readonly property string iconClipboard:
        "M 9,4 L 5.5,4 L 5.5,21 L 18.5,21 L 18.5,4 L 15,4"
        + " M 9,2.5 L 15,2.5 L 15,6 L 9,6 Z"
        + " M 8.5,10.5 L 15.5,10.5 M 8.5,14 L 15.5,14 M 8.5,17.5 L 12.5,17.5"
    readonly property string iconCalculator:
        "M 6.5,2.5 L 17.5,2.5 A 1.5,1.5 0 0,1 19,4 L 19,20 A 1.5,1.5 0 0,1 17.5,21.5"
        + " L 6.5,21.5 A 1.5,1.5 0 0,1 5,20 L 5,4 A 1.5,1.5 0 0,1 6.5,2.5 Z"
        + " M 7.5,5.5 L 16.5,5.5 L 16.5,9.5 L 7.5,9.5 Z"
        + " M 8.5,13 L 8.5,13.1 M 12,13 L 12,13.1 M 15.5,13 L 15.5,13.1"
        + " M 8.5,16.5 L 8.5,16.6 M 12,16.5 L 12,16.6 M 15.5,16.5 L 15.5,16.6"
    readonly property string iconEmoji:
        "M 12,2.5 A 9.5,9.5 0 1,0 12,21.5 A 9.5,9.5 0 1,0 12,2.5 Z"
        + " M 8.7,9.5 L 8.7,9.6 M 15.3,9.5 L 15.3,9.6"
        + " M 7.8,14 A 5,5 0 0,0 16.2,14"
    readonly property string iconClock:
        "M 12,3 A 9,9 0 1,0 12,21 A 9,9 0 1,0 12,3 Z"
        + " M 12,7 L 12,12 L 15.5,14"
    readonly property string iconCamera:
        "M 3.5,7.5 L 8,7.5 L 10,5 L 14,5 L 16,7.5 L 20.5,7.5 L 20.5,19.5 L 3.5,19.5 Z"
        + " M 12,9.5 A 3.5,3.5 0 1,0 12,16.5 A 3.5,3.5 0 1,0 12,9.5 Z"
    readonly property string iconPin:
        "M 9.5,3 L 14.5,3 L 14.5,10 L 16.5,12.5 L 7.5,12.5 L 9.5,10 Z"
        + " M 12,12.5 L 12,21"
    readonly property string iconTrash:
        "M 4.5,6.5 L 19.5,6.5"
        + " M 9,6.5 L 9,4.5 A 1,1 0 0,1 10,3.5 L 14,3.5 A 1,1 0 0,1 15,4.5 L 15,6.5"
        + " M 6.5,6.5 L 7.5,20 A 1.2,1.2 0 0,0 8.7,21 L 15.3,21 A 1.2,1.2 0 0,0 16.5,20"
        + " L 17.5,6.5 M 10.3,10 L 10.3,17 M 13.7,10 L 13.7,17"
    readonly property string iconPlus: "M 12,5 L 12,19 M 5,12 L 19,12"
    readonly property string iconStop: "M 7,7 L 17,7 L 17,17 L 7,17 Z"
    readonly property string iconRecord:
        "M 12,6 A 6,6 0 1,0 12,18 A 6,6 0 1,0 12,6 Z"
    readonly property string iconStopwatch:
        "M 12,4.5 A 8,8 0 1,0 12,20.5 A 8,8 0 1,0 12,4.5 Z"
        + " M 10,2 L 14,2 M 12,2 L 12,4.5"
        + " M 12,8 L 12,12 L 15,14"
    readonly property string iconTimer:
        "M 7,3 L 17,3 M 7,21 L 17,21"
        + " M 8,3 L 8,7 A 4,4 0 0,0 12,12 A 4,4 0 0,1 16,17 L 16,21"
        + " M 16,3 L 16,7 A 4,4 0 0,1 12,12 A 4,4 0 0,0 8,17 L 8,21"
    readonly property string iconBackspace:
        "M 8,5 L 21,5 L 21,19 L 8,19 L 2.5,12 Z"
        + " M 11.5,9.5 L 17,14.5 M 17,9.5 L 11.5,14.5"
    readonly property string iconCheck: "M 5,12.5 L 10,17.5 L 19,7"
    readonly property string iconBell:
        "M 12,3 A 6,6 0 0,1 18,9 L 18,14 L 20,16.5 L 4,16.5 L 6,14 L 6,9"
        + " A 6,6 0 0,1 12,3 Z M 10,19.5 A 2,2 0 0,0 14,19.5"
    readonly property string iconBellOff:
        "M 9.5,4.2 A 6,6 0 0,1 18,9 L 18,14 L 20,16.5 L 4,16.5 L 6,14"
        + " L 6,9 A 6,6 0 0,1 8.2,4.9 M 10,19.5 A 2,2 0 0,0 14,19.5"
        + " M 4,4 L 20,20"
    readonly property string iconChevronUp: "M 6,14.5 L 12,9 L 18,14.5"
    readonly property string iconChevronDown: "M 6,9.5 L 12,15 L 18,9.5"

    // === иконки действий сообщений кота-агента ===
    // перегенерировать: круговая стрелка
    readonly property string iconRefresh:
        "M 20,12 A 8,8 0 1,1 17.7,6.3 M 20,4 L 20,8.5 L 15.5,8.5"
    // продолжить: двойная шевронная стрелка вправо
    readonly property string iconContinue:
        "M 6,6 L 12,12 L 6,18 M 13,6 L 19,12 L 13,18"
    // форк чата: ветвление
    readonly property string iconFork:
        "M 7,8 A 2.5,2.5 0 1,1 6.99,8 M 7,10.5 L 7,19"
        + " M 7,12 C 7,8 17,10 17,7.5 M 17,8 A 2.5,2.5 0 1,1 16.99,8"
    // копировать: две карточки
    readonly property string iconCopy:
        "M 9,8 L 20,8 L 20,20 L 9,20 Z M 4,16 L 4,4 L 15,4"
    // редактировать: карандаш
    readonly property string iconEdit:
        "M 4,20 L 5,16 L 15.5,5.5 L 18.5,8.5 L 8,19 L 4,20 Z M 13.5,7.5 L 16.5,10.5"
    // поиск в интернете: глобус
    readonly property string iconGlobe:
        "M 12,3 A 9,9 0 1,0 12.01,3 M 3,12 L 21,12"
        + " M 12,3 C 15,6.5 15,17.5 12,21 C 9,17.5 9,6.5 12,3"
    // терминал: окно с промптом
    readonly property string iconTerminal:
        "M 3.5,5 L 20.5,5 L 20.5,19 L 3.5,19 Z M 7,9 L 10.5,12 L 7,15 M 12.5,15 L 16.5,15"
    // вопрос юзеру: опрос с галочками
    readonly property string iconAsk:
        "M 4,6 L 9,6 M 4,12 L 9,12 M 4,18 L 9,18 M 12,6 L 20,6"
        + " M 12,12 L 20,12 M 12,18 L 20,18"
    // глаз — просмотр изображения
    readonly property string iconEye:
        "M 2.5,12 C 5,7.2 8.5,5.5 12,5.5 C 15.5,5.5 19,7.2 21.5,12"
        + " C 19,16.8 15.5,18.5 12,18.5 C 8.5,18.5 5,16.8 2.5,12 Z"
        + " M 12,9.5 A 2.5,2.5 0 1,0 12.01,9.5"
}
