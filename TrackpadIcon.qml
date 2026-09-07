import QtQuick
import qs.Commons

// Hollow Magic Trackpad: landscape rounded outline, charge meter inside.
// Filled slabs read as a blob at bar size; this is for the panel hero.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property color lowColor: color
  property real fraction: 0
  property bool low: false

  readonly property real padW: iconSize * 1.15
  readonly property real padH: iconSize * 0.78
  readonly property real padRadius: padH * 0.18
  readonly property real stroke: Math.max(1.6, iconSize * 0.07)

  width: padW
  height: iconSize
  implicitWidth: padW
  implicitHeight: iconSize

  Rectangle {
    id: body
    width: root.padW
    height: root.padH
    anchors.centerIn: parent
    radius: root.padRadius
    color: "transparent"
    border.width: root.stroke
    border.color: root.color
  }

  Row {
    visible: root.iconSize >= 22
    anchors.horizontalCenter: body.horizontalCenter
    anchors.top: body.top
    anchors.topMargin: body.height * 0.22
    spacing: body.width * 0.09

    Repeater {
      model: 3
      Rectangle {
        width: Math.max(3, body.width * 0.09)
        height: width
        radius: width / 2
        color: root.color
        opacity: 0.75
      }
    }
  }

  Rectangle {
    width: Math.max(0, (body.width - root.stroke * 4) * Math.max(0, Math.min(1, root.fraction)))
    height: Math.max(2.5, body.height * 0.14)
    radius: height / 2
    color: root.low ? root.lowColor : root.color
    anchors.left: body.left
    anchors.bottom: body.bottom
    anchors.leftMargin: root.stroke * 2
    anchors.bottomMargin: root.stroke * 1.6
  }
}
