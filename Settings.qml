pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    property alias barGap: settings.barGap
    property alias barHeight: settings.barHeight
    property alias leftMargin: settings.leftMargin
    property alias rightMargin: settings.rightMargin
    property alias edgeSize: settings.edgeSize
    property alias barColor: settings.barColor

    FileView {
        id: configFile

        path: Qt.resolvedUrl("./settings.json")
        watchChanges: true
        adapter: JsonAdapter {
            id: settings

            property int barGap: 20
            property int barHeight: 40
            property int leftMargin: 100
            property int rightMargin: 100
            property int edgeSize: 20
            property string barColor: "#ffffff"
        }

        onAdapterUpdated: writeAdapter()

        onFileChanged: reload()
    }
}