import QtQuick
import Quickshell
import Quickshell.Io

Process {
  id: proc

  property int maxBytes: 8192
  property int deadlineMs: 20000
  property string buf: ""
  property var extraEnv: ({})

  signal accepted(string text)
  signal finished(int code)

  clearEnvironment: true
  environment: proc.extraEnv

  stdout: SplitParser {
    splitMarker: ""
    onRead: function(chunk) {
      proc.buf += chunk
      if (proc.buf.length > proc.maxBytes) {
        proc.signal(15)
        killTimer.start()
        proc.buf = ""
      }
    }
  }

  stderr: SplitParser {
    splitMarker: ""
    onRead: function(chunk) {
      if (proc.buf.length > proc.maxBytes) {
        proc.signal(15)
        killTimer.start()
      }
    }
  }

  onRunningChanged: {
    if (running) {
      proc.buf = ""
      deadline.restart()
    } else {
      deadline.stop()
    }
  }

  onExited: function(code) {
    deadline.stop()
    killTimer.stop()
    if (code === 0 && proc.buf.length)
      proc.accepted(proc.buf)
    proc.buf = ""
    proc.finished(code)
  }

  Timer {
    id: deadline
    interval: proc.deadlineMs
    onTriggered: {
      proc.signal(15)
      killTimer.start()
    }
  }

  Timer {
    id: killTimer
    interval: 2000
    onTriggered: proc.signal(9)
  }

  Component.onDestruction: if (proc.running) proc.signal(15)
}
