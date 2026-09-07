import QtQuick
import qs.Commons

// Top-down Magic Trackpad: wide rounded slab, no button split.
// 160 × 114.9 mm. At bar size this is just a landscape rounded rect;
// the panel hero is large enough for the inset glass.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  readonly property real padW: iconSize
  readonly property real padH: iconSize * 0.72
  readonly property real padRadius: padH * 0.18

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
    color: root.color
  }

  Rectangle {
    visible: root.iconSize >= 22
    width: body.width * 0.78
    height: body.height * 0.62
    radius: height * 0.16
    color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.28)
    anchors.centerIn: body
    anchors.verticalCenterOffset: body.height * 0.04
  }
}
