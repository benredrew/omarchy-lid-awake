import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// While on, a transient user unit holds a logind handle-lid-switch inhibitor,
// so closing the lid locks the session (Omarchy's own lid binding) but does
// not suspend. Stopping the unit releases it; a reboot clears it too.
BarWidget {
  id: root
  moduleName: "benredrew.lid-awake"

  readonly property string unitName: "lid-awake"
  property bool lidAwake: false
  property bool refreshPending: false

  function refresh() {
    // A check already running may have sampled the unit before a change, so
    // run one more after it rather than dropping this request.
    if (statusProc.running || switchProc.running) {
      root.refreshPending = true
      return
    }
    statusProc.running = true
  }

  function toggle() {
    if (switchProc.running) return
    switchProc.command = root.lidAwake
      ? ["systemctl", "--user", "stop", root.unitName]
      : ["systemd-run", "--user", "--collect", "--quiet", "--unit=" + root.unitName,
         "--property=Restart=on-failure", "--property=RestartSec=1",
         "systemd-inhibit", "--what=handle-lid-switch", "--mode=block",
         "--who=Lid Awake", "--why=Stay running with the lid closed",
         "sleep", "infinity"]
    switchProc.running = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: statusProc
    command: ["systemctl", "--user", "--quiet", "is-active", root.unitName]
    onExited: function(exitCode) {
      root.lidAwake = exitCode === 0
      if (root.refreshPending) {
        root.refreshPending = false
        root.refresh()
      }
    }
  }

  Process {
    id: switchProc
    onExited: root.refresh()
  }

  Component.onCompleted: refresh()

  // The unit can fail, restart, or stop outside the widget, for example with
  // `systemctl --user stop`. Its journal logs every change, so follow it rather
  // than poll: lines wait in the pipe while the shell is busy, so none is
  // missed. pdeathsig stops the follower if the shell dies without cleaning up.
  Process {
    id: unitFollower
    running: true
    command: ["setpriv", "--pdeathsig", "TERM", "journalctl", "--user", "--follow", "--lines=0", "--output=cat", "--unit=" + root.unitName]
    stdout: SplitParser {
      onRead: root.refresh()
    }
    onExited: followerRestart.start()
  }

  // Changes logged while the follower was down are not replayed, so check the
  // unit again once it is back.
  Timer {
    id: followerRestart
    interval: 5000
    onTriggered: {
      unitFollower.running = true
      root.refresh()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰌢"
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    dimmed: !root.lidAwake
    useActiveColor: false
    tooltipText: root.lidAwake ? "Allow Lid-Close Suspend" : "Stay On With Lid Closed"
    onPressed: root.toggle()
  }
}
