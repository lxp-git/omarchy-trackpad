import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "xuanping.trackpad"
  ipcTarget: "xuanping.trackpad"
  manageIpc: false

  readonly property string helper: {
    var resolved = Model.helperPathFromUrl(Qt.resolvedUrl("bin/trackpad-pack"))
    if (resolved && resolved.indexOf("trackpad-pack") >= 0) return resolved
    return (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/xuanping.trackpad/bin/trackpad-pack"
  }
  readonly property var upowerDevices: UPower.devices ? UPower.devices.values : []
  readonly property var upowerDevice: Model.preferredDevice(upowerDevices)
  property var sysBattery: Model.emptyBattery()
  property int absentStreak: 0
  PersistentProperties {
    id: held
    reloadableId: "xuanping-trackpad-bar"
    property bool present: false
    property int percentage: -1
    property string status: "Disconnected"
    property string model: ""
  }
  readonly property var upowerBattery: {
    var d = upowerDevice
    if (!d || d.isPresent === false) return null
    var pct = Model.percentFromNumber(d.percentage)
    var unknown = d.state === UPowerDeviceState.Unknown
    // After a Bluetooth reset the kernel often reports 0% / Unknown.
    // Keep the widget visible; do not treat that 0% as a real reading.
    if (pct <= 0 || unknown) {
      return {
        present: true,
        percentage: pct > 0 ? pct : -1,
        status: unknown ? "Unknown" : "Discharging",
        model: d.model || "",
        stale: false,
        source: "upower"
      }
    }
    var chargingNow = d.state === UPowerDeviceState.Charging || d.state === UPowerDeviceState.PendingCharge
    var full = d.state === UPowerDeviceState.FullyCharged
    return {
      present: true,
      percentage: pct,
      status: chargingNow ? "Charging" : (full ? "Full" : "Discharging"),
      model: d.model || "",
      stale: false,
      source: "upower"
    }
  }
  readonly property var heldBattery: held.present ? {
    present: true,
    percentage: held.percentage,
    status: held.status,
    model: held.model,
    stale: true,
    source: "hold"
  } : null
  readonly property var battery: {
    if (sysBattery && sysBattery.present && sysBattery.percentage > 0) return sysBattery
    if (upowerBattery && upowerBattery.percentage > 0) return upowerBattery
    if (sysBattery && sysBattery.present) return sysBattery
    if (upowerBattery) return upowerBattery
    return heldBattery || sysBattery
  }
  readonly property bool devicePresent: !!(battery && battery.present) || held.present
  readonly property int percentage: battery && isFinite(battery.percentage) ? battery.percentage : -1
  readonly property real batteryFraction: percentage < 0 ? 0 : percentage / 100
  readonly property bool charging: !!(battery && battery.status === "Charging")
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property bool showPercentage: setting("showPercentage", true) !== false
  readonly property bool barShowsPercent: !vertical && showPercentage && percentage >= 0
  readonly property bool stale: !!(battery && battery.stale)
  readonly property bool lowBattery: devicePresent && !charging && !stale && percentage > 0 && percentage <= 20
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color barIconColor: button.active && button.useActiveColor ? button.activeColor : button.foreground
  readonly property real openPanelIndicatorWidth: barShowsPercent && !button.vertical ? button.slotSize * 0.72 : 0

  property bool drag3fg: true
  property bool swipe4: true
  property bool macosAccel: true
  property bool packBusy: false
  property bool cursorActive: false
  property int feelIndex: 0
  readonly property var feelKeys: ["drag3fg", "swipe4", "macosAccel"]
  readonly property bool anyFeel: drag3fg || swipe4 || macosAccel

  readonly property string deviceName: Model.displayName({ model: battery && battery.model ? battery.model : "" })
  readonly property string heroStatus: {
    if (!devicePresent) return "Disconnected"
    if (stale) return "Last reading"
    if (percentage < 0) return "Waiting"
    if (battery && battery.status === "Full") return "Charged"
    if (charging) return "Charging"
    return "Discharging"
  }

  function refreshPack() {
    if (!helper || statusProc.running) return
    statusProc.command = [helper, "status"]
    statusProc.running = true
  }

  function refreshBattery() {
    if (!helper || batteryProc.running) return
    batteryProc.command = [helper, "battery"]
    batteryProc.running = true
  }

  function applyStatus(parsed) {
    root.drag3fg = parsed.drag3fg
    root.swipe4 = parsed.swipe4
    root.macosAccel = parsed.macosAccel
  }

  function applyBattery(parsed) {
    if (parsed && parsed.present) {
      var pct = parsed.percentage
      var stale = !!parsed.stale
      if (!(pct > 0) && held.percentage > 0) {
        pct = held.percentage
        stale = true
      }
      root.absentStreak = 0
      root.sysBattery = {
        present: true,
        percentage: pct,
        status: parsed.status || held.status,
        model: parsed.model || held.model,
        stale: stale,
        source: parsed.source || ""
      }
      held.present = true
      if (pct > 0) held.percentage = pct
      if (parsed.status && parsed.status !== "Unknown") held.status = parsed.status
      if (parsed.model) held.model = parsed.model
      return
    }
    root.absentStreak += 1
    if (root.absentStreak < 3 && held.present)
      return
    held.present = false
    root.sysBattery = parsed || Model.emptyBattery()
  }

  function featureOn(key) {
    if (key === "swipe4") return root.swipe4
    if (key === "macosAccel") return root.macosAccel
    return root.drag3fg
  }

  function setFeatureOptimistic(key, on) {
    if (key === "swipe4") root.swipe4 = on
    else if (key === "macosAccel") root.macosAccel = on
    else root.drag3fg = on
  }

  function toggleFeature(key) {
    if (!helper || packProc.running) return
    if (root.feelKeys.indexOf(key) < 0) return
    packBusy = true
    setFeatureOptimistic(key, !featureOn(key))
    packProc.command = [helper, "toggle", key]
    packProc.running = true
  }

  function togglePercentage() {
    root.settings = Object.assign({}, root.settings, { showPercentage: !root.showPercentage })
    if (root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName, root.settings)
  }

  IpcHandler {
    target: "xuanping.trackpad"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function toggleDrag(): void { root.toggleFeature("drag3fg") }
    function toggleSwipe(): void { root.toggleFeature("swipe4") }
    function toggleAccel(): void { root.toggleFeature("macosAccel") }
    function togglePercentage(): void { root.togglePercentage() }
  }

  visible: devicePresent
  implicitWidth: devicePresent ? button.implicitWidth : 0
  implicitHeight: devicePresent ? button.implicitHeight : 0
  onDevicePresentChanged: if (!devicePresent) close()

  Process {
    id: statusProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.applyStatus(Model.parseStatus(text))
      }
    }
  }

  Process {
    id: batteryProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { root.applyBattery(Model.parseBattery(text)) }
    }
  }

  Process {
    id: packProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.applyStatus(Model.parseStatus(text))
      }
    }
    onExited: root.packBusy = false
  }

  Timer {
    interval: 8000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.refreshBattery()
      if (root.opened) root.refreshPack()
    }
  }

  Component.onCompleted: {
    root.refreshBattery()
    root.refreshPack()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    active: root.lowBattery
    dimmed: !root.anyFeel
    opticalSize: Style.bar.iconCanvas
    slotSize: Style.bar.iconSlot * (root.barShowsPercent ? 2 : 1)
    tooltipText: ""
    iconComponent: Component {
      Item {
        Row {
          anchors.centerIn: parent
          spacing: Style.space(3)

          Text {
            textFormat: Text.PlainText
            text: Model.icon()
            color: root.barIconColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.icon
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            visible: root.barShowsPercent
            textFormat: Text.PlainText
            text: root.percentage + "%"
            color: root.barIconColor
            font.family: root.fontFamily
            font.pixelSize: Style.bar.iconFont
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
    onPressed: function(b) {
      if (!root.devicePresent) return
      if (b === Qt.RightButton) root.togglePercentage()
      else if (b === Qt.MiddleButton) {
        root.refreshBattery()
        root.refreshPack()
      } else {
        root.toggle()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.devicePresent
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) {
          root.cursorActive = true
          return
        }
        if (dy !== 0) root.feelIndex = Math.max(0, Math.min(2, root.feelIndex + dy))
      }
      onActivateRequested: if (root.cursorActive) root.toggleFeature(root.feelKeys[root.feelIndex])
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroPercent.implicitHeight)

          TrackpadIcon {
            id: heroIcon
            iconSize: Style.font.display
            color: root.lowBattery ? root.urgent : root.foreground
            lowColor: root.urgent
            fraction: root.batteryFraction
            low: root.lowBattery
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroPercent.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: root.deviceName
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.heroStatus.toUpperCase()
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Text {
            id: heroPercent
            textFormat: Text.PlainText
            text: root.percentage >= 0 ? (root.percentage + "%") : "—"
            color: root.lowBattery ? root.urgent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Item {
          width: parent.width
          implicitHeight: Style.space(8)

          Rectangle {
            id: barTrack
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
          }

          Rectangle {
            id: barFill
            anchors.left: barTrack.left
            anchors.verticalCenter: barTrack.verticalCenter
            height: barTrack.height
            radius: barTrack.radius
            color: root.lowBattery ? root.urgent : root.foreground
            width: Math.max(barTrack.height, barTrack.width * root.batteryFraction)

            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

            SequentialAnimation on opacity {
              running: root.charging && root.opened
              loops: Animation.Infinite
              alwaysRunToEnd: true
              NumberAnimation { from: 1.0; to: 0.55; duration: 950; easing.type: Easing.InOutSine }
              NumberAnimation { from: 0.55; to: 1.0; duration: 950; easing.type: Easing.InOutSine }
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        Toggle {
          width: parent.width
          label: "Show percentage"
          description: "Battery percent after the bar icon. Right-click also toggles this."
          foreground: root.foreground
          fontFamily: root.fontFamily
          checked: root.showPercentage
          onClicked: root.togglePercentage()
        }

        PanelSeparator { foreground: root.foreground }

        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "FEEL"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Toggle {
            width: parent.width
            label: "Three-finger drag"
            description: "Click-and-drag with three fingers."
            foreground: root.foreground
            fontFamily: root.fontFamily
            checked: root.drag3fg
            hasCursor: root.cursorActive && root.feelIndex === 0
            onHovered: function(h) { if (h) { root.cursorActive = true; root.feelIndex = 0 } }
            onClicked: root.toggleFeature("drag3fg")
          }

          Toggle {
            width: parent.width
            label: "Four-finger swipe"
            description: "Pan across workspaces with four fingers."
            foreground: root.foreground
            fontFamily: root.fontFamily
            checked: root.swipe4
            hasCursor: root.cursorActive && root.feelIndex === 1
            onHovered: function(h) { if (h) { root.cursorActive = true; root.feelIndex = 1 } }
            onClicked: root.toggleFeature("swipe4")
          }

          Toggle {
            width: parent.width
            label: "macOS pointer curve"
            description: "The same custom libinput accel macOS uses."
            foreground: root.foreground
            fontFamily: root.fontFamily
            checked: root.macosAccel
            hasCursor: root.cursorActive && root.feelIndex === 2
            onHovered: function(h) { if (h) { root.cursorActive = true; root.feelIndex = 2 } }
            onClicked: root.toggleFeature("macosAccel")
          }
        }
      }
    }
  }
}
