pragma Singleton

import QtQuick
import Quickshell

// Каталог глифов иконок: координатное поле 24x24, рисуются VIcon.
// fillPath — заливка, strokePath — штрих (обводка линии).
Singleton {
    id: glyphs

    readonly property string iconVolumeBody:
        "M 3,9 L 7,9 L 12,4.5 L 12,19.5 L 7,15 L 3,15 Z"
    readonly property string iconVolumeWaves:
        "M 15,9.5 C 16.5,10.8 16.5,13.2 15,14.5 M 17.6,7 C 20.3,9.6 20.3,14.4 17.6,17"
    readonly property string iconVolumeMuted:
        "M 15.5,9.5 L 20.5,14.5 M 20.5,9.5 L 15.5,14.5"
    readonly property string iconBrightness:
        "M 12,7.6 A 4.4,4.4 0 1,0 12,16.4 A 4.4,4.4 0 1,0 12,7.6 Z"
        + " M 12,1.8 L 12,4.4 M 12,19.6 L 12,22.2 M 1.8,12 L 4.4,12 M 19.6,12 L 22.2,12"
        + " M 4.6,4.6 L 6.5,6.5 M 17.5,17.5 L 19.4,19.4 M 4.6,19.4 L 6.5,17.5 M 17.5,6.5 L 19.4,4.6"
    readonly property string iconNote:
        "M 6,18.6 A 2.6,2.6 0 1,0 11.2,18.6 A 2.6,2.6 0 1,0 6,18.6 Z"
        + " M 11.2,18.6 L 11.2,5.2 L 19.5,3.5 L 19.5,7.6 L 11.2,9.3 Z"
    readonly property string iconPlay: "M 7.5,4.5 L 19.5,12 L 7.5,19.5 Z"
    readonly property string iconPause:
        "M 6.5,5 L 10,5 L 10,19 L 6.5,19 Z M 14,5 L 17.5,5 L 17.5,19 L 14,19 Z"
    readonly property string iconPrev:
        "M 18.5,5 L 18.5,19 L 7.5,12 Z M 5,5 L 7.6,5 L 7.6,19 L 5,19 Z"
    readonly property string iconNext:
        "M 5.5,5 L 5.5,19 L 16.5,12 Z M 16.4,5 L 19,5 L 19,19 L 16.4,19 Z"
    readonly property string iconPowerStroke:
        "M 18.36,6.64 A 9,9 0 1,1 5.64,6.64 M 12,2 L 12,10"
    readonly property string iconRebootStroke:
        "M 22.4,4.6 L 22.4,10 L 17,10 M 20.1,14.6 A 8.4,8.4 0 1,1 18.1,6.1 L 22.4,10"
    readonly property string iconMoonFill:
        "M 21,12.79 A 9,9 0 1,1 11.21,3 A 7,7 0 0,0 21,12.79 Z"
    readonly property string iconHibernateStroke:
        "M 4,5 L 11.5,5 L 4,13 L 11.5,13 M 14,12 L 19.5,12 L 14,18.5 L 19.5,18.5"
    readonly property string iconLockFill:
        "M 5.5,10.5 L 18.5,10.5 L 18.5,20.5 L 5.5,20.5 Z"
    readonly property string iconLockStroke:
        "M 8.5,10.5 L 8.5,7.5 A 3.5,3.5 0 0,1 15.5,7.5 L 15.5,10.5"
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
}
