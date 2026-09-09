import QtQuick
import Quickshell
import Quickshell.Io

// Process is PostReloadHook, not Item: Timers must be siblings of Process.
Item {
  id: root
  width: 0
  height: 0

  property int maxBytes: 8192
  property int deadlineMs: 20000
  property string buf: ""
  property var extraEnv: ({})
  property alias command: helperProc.command
  property alias running: helperProc.running

  signal accepted(string text)
  signal finished(int code)

  Process {
    id: helperProc
    clearEnvironment: true
    environment: root.extraEnv

    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        root.buf += chunk
        if (root.buf.length > root.maxBytes) {
          helperProc.signal(15)
          killTimer.start()
          root.buf = ""
        }
      }
    }

    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        if (root.buf.length > root.maxBytes) {
          helperProc.signal(15)
          killTimer.start()
        }
      }
    }

    onRunningChanged: {
      if (running) {
        root.buf = ""
        deadline.restart()
      } else {
        deadline.stop()
      }
    }

    onExited: function(code) {
      deadline.stop()
      killTimer.stop()
      if (code === 0 && root.buf.length)
        root.accepted(root.buf)
      root.buf = ""
      root.finished(code)
    }
  }

  Timer {
    id: deadline
    interval: root.deadlineMs
    onTriggered: {
      helperProc.signal(15)
      killTimer.start()
    }
  }

  Timer {
    id: killTimer
    interval: 2000
    onTriggered: helperProc.signal(9)
  }

  Component.onDestruction: if (helperProc.running) helperProc.signal(15)
}
