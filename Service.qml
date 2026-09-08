import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var settings: ({})

  readonly property string helper: Model.resolveHelper(Qt.resolvedUrl("bin/trackpad-pack"), Quickshell.env("HOME") || "")
  readonly property var helperEnv: Model.helperEnv(function(k) { return Quickshell.env(k) })
  property var battery: Model.emptyBattery()
  readonly property int percentage: battery && isFinite(battery.percentage) ? battery.percentage : -1
  readonly property bool charging: {
    var status = battery && battery.status ? String(battery.status) : ""
    return status === "Charging" || status === "Full"
  }

  readonly property int warnPercent: 20
  readonly property int criticalPercent: 10

  PersistentProperties {
    id: persisted
    reloadableId: "xuanping-trackpad"
    property int lastNotifiedPercent: 100
  }

  property bool notifyLoaded: false

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

  function loadNotify() {
    if (!helper || notifyGetProc.running) return
    notifyGetProc.command = [helper, "notify-get"]
    notifyGetProc.running = true
  }

  function hydrateNotify(raw) {
    if (notifyLoaded) return
    persisted.lastNotifiedPercent = Model.parseNotify(raw)
    notifyLoaded = true
    root.refreshBattery()
  }

  function setLastNotified(value) {
    if (persisted.lastNotifiedPercent === value) return
    persisted.lastNotifiedPercent = value
    if (!notifyLoaded || !helper || notifySetProc.running) return
    notifySetProc.command = [helper, "notify-set", String(value)]
    notifySetProc.running = true
  }

  function checkBattery() {
    if (!notifyLoaded) return
    if (charging) {
      setLastNotified(100)
      return
    }
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
    var n = parseInt(level, 10)
    if (!isFinite(n) || n < 1 || n > 100) return
    notifyProc.command = [
      "/usr/bin/omarchy-notification-send",
      "--app-name", "Trackpad",
      "-g", "󰟸",
      "-u", urgency,
      "-t", "15000",
      "Trackpad battery",
      "Down to " + n + "%"
    ]
    notifyProc.running = true
  }

  HelperProcess {
    id: applyProc
    extraEnv: root.helperEnv
    maxBytes: 8192
  }

  HelperProcess {
    id: notifyGetProc
    extraEnv: root.helperEnv
    maxBytes: 1024
    onAccepted: root.hydrateNotify(text)
  }

  HelperProcess {
    id: notifySetProc
    extraEnv: root.helperEnv
    maxBytes: 1024
  }

  Process {
    id: notifyProc
  }

  HelperProcess {
    id: batteryProc
    extraEnv: root.helperEnv
    maxBytes: 4096
    onAccepted: {
      root.battery = Model.parseBattery(text)
      root.checkBattery()
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
    root.loadNotify()
  }
}
