import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var settings: ({})

  readonly property string helper: {
    var resolved = Model.helperPathFromUrl(Qt.resolvedUrl("bin/trackpad-pack"))
    if (resolved && resolved.indexOf("trackpad-pack") >= 0) return resolved
    return (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/xuanping.trackpad/bin/trackpad-pack"
  }
  property var battery: Model.emptyBattery()
  readonly property int percentage: battery && isFinite(battery.percentage) ? battery.percentage : -1
  readonly property bool charging: {
    var status = battery && battery.status ? String(battery.status) : ""
    return status === "Charging" || status === "Full"
  }

  // macOS Magic Trackpad/Mouse: one banner at ~2%, since at least Mojave.
  // Do not treat kernel 0% / stale HID as a new discharge cycle.
  readonly property int lowBatteryPercent: 2

  PersistentProperties {
    id: persisted
    reloadableId: "xuanping-trackpad"
    property bool notifiedLow: false
  }

  function applyPack() {
    if (!helper || applyProc.running) return
    applyProc.command = [helper, "apply"]
    applyProc.running = true
  }

  function refreshBattery() {
    if (!helper || batteryProc.running) return
    batteryProc.command = [helper, "battery"]
    batteryProc.running = true
  }

  function checkBattery() {
    if (charging) {
      persisted.notifiedLow = false
      return
    }
    if (!battery || !battery.present || battery.stale || percentage <= 0)
      return
    if (percentage <= lowBatteryPercent) {
      if (!persisted.notifiedLow) {
        notifyBattery(percentage, "critical")
        persisted.notifiedLow = true
      }
      return
    }
    persisted.notifiedLow = false
  }

  function notifyBattery(level, urgency) {
    if (notifyProc.running) return
    notifyProc.command = [
      "omarchy-notification-send",
      "--app-name", "Trackpad",
      "-g", "󰟸",
      "-u", urgency,
      "-t", "15000",
      "Trackpad battery",
      "Down to " + level + "%"
    ]
    notifyProc.running = true
  }

  Process { id: applyProc }
  Process { id: notifyProc }
  Process {
    id: batteryProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.battery = Model.parseBattery(text)
        root.checkBattery()
      }
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshBattery()
  }

  Component.onCompleted: {
    root.applyPack()
    root.refreshBattery()
  }
}
