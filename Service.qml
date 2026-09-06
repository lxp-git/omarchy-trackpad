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

  PersistentProperties {
    id: persisted
    reloadableId: "xuanping-trackpad"
    property int lastNotifiedPercent: 100
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
    if (!battery || !battery.present || battery.stale || percentage <= 0 || charging) {
      persisted.lastNotifiedPercent = 100
      return
    }
    if (percentage <= 10 && persisted.lastNotifiedPercent > 10) {
      notifyBattery(percentage, "critical")
      persisted.lastNotifiedPercent = percentage
    } else if (percentage <= 20 && persisted.lastNotifiedPercent > 20) {
      notifyBattery(percentage, "normal")
      persisted.lastNotifiedPercent = percentage
    } else if (percentage > 20) {
      persisted.lastNotifiedPercent = 100
    }
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
