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

  readonly property int warnPercent: 20
  readonly property int criticalPercent: 10
  readonly property string notifyDir: {
    var home = Quickshell.env("HOME") || ""
    var xdg = Quickshell.env("XDG_STATE_HOME")
    var dir = (xdg && xdg.length) ? xdg : (home + "/.local/state")
    return dir + "/omarchy/xuanping.trackpad"
  }
  readonly property string notifyPath: notifyDir + "/notify.json"

  PersistentProperties {
    id: persisted
    reloadableId: "xuanping-trackpad"
    property int lastNotifiedPercent: 100
  }

  property bool notifyLoaded: false

  FileView {
    id: notifyFile
    path: root.notifyPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.hydrateNotify(text())
    onLoadFailed: root.hydrateNotify("")
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

  function hydrateNotify(raw) {
    if (notifyLoaded) return
    try {
      var text = String(raw || "")
      var start = text.indexOf("{")
      var end = text.lastIndexOf("}")
      if (start >= 0 && end > start) {
        var parsed = JSON.parse(text.substring(start, end + 1))
        var n = parseInt(parsed.lastNotifiedPercent, 10)
        if (isFinite(n) && n >= 0 && n <= 100)
          persisted.lastNotifiedPercent = n
      }
    } catch (e) {
    }
    notifyLoaded = true
    root.refreshBattery()
  }

  function setLastNotified(value) {
    if (persisted.lastNotifiedPercent === value) return
    persisted.lastNotifiedPercent = value
    if (!notifyLoaded) return
    notifyFile.setText(JSON.stringify({ lastNotifiedPercent: value }) + "\n")
  }

  function checkBattery() {
    if (!notifyLoaded) return
    if (charging) {
      setLastNotified(100)
      return
    }
    // Kernel 0% / stale HID after a Bluetooth reset is not a new cycle.
    if (!battery || !battery.present || battery.stale || percentage <= 0)
      return
    if (percentage <= criticalPercent && persisted.lastNotifiedPercent > criticalPercent) {
      notifyBattery(percentage, "critical")
      setLastNotified(percentage)
    } else if (percentage <= warnPercent && persisted.lastNotifiedPercent > warnPercent) {
      notifyBattery(percentage, "normal")
      setLastNotified(percentage)
    } else if (percentage > warnPercent) {
      setLastNotified(100)
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
    id: mkdirProc
    onExited: notifyFile.reload()
  }
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
    if (notifyDir && !mkdirProc.running) {
      mkdirProc.command = ["mkdir", "-p", notifyDir]
      mkdirProc.running = true
    }
  }
}
