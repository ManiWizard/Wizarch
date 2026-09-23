import QtQuick
Image {
    property string name: "apps"
    source: Qt.resolvedUrl("../assets/icons/" + name + ".svg")
    sourceSize: Qt.size(32, 32)
    fillMode: Image.PreserveAspectFit
    smooth: true
}
