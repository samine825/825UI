pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    property alias barGap: settings.barGap
    property alias barHeight: settings.barHeight
    property alias line: settings.line
    property alias leftMargin: settings.leftMargin
    property alias rightMargin: settings.rightMargin
    property alias edgeSize: settings.edgeSize
    property alias c1: settings.c1
    property alias c2: settings.c2
    property alias barType: settings.barType
    property alias secondsMode: settings.secondsMode
    property alias infex: settings.infex

    FileView {
        id: configFile

        path: Qt.resolvedUrl("./settings.json")
        watchChanges: true
        adapter: JsonAdapter {
            id: settings

            property int barGap: 20
            property int barHeight: 70
            property int line: 5
            property int leftMargin: 100
            property int rightMargin: 100
            property int edgeSize: 20
            property string c1: "#ffffff"
            property string c2: "#000000"
            property int barType: 0
            property int secondsMode: 0
            property bool infex: true
        }

        onAdapterUpdated: writeAdapter()

        onFileChanged: reload()
    }
}
