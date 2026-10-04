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

  function refresh() {
    if (!statusProc.running && !switchProc.running) statusProc.running = true
  }

  function toggle() {
    if (switchProc.running) return
    switchProc.command = root.lidAwake
      ? ["systemctl", "--user", "stop", root.unitName]
      : ["systemd-run", "--user", "--collect", "--quiet", "--unit=" + root.unitName,
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
    onExited: function(exitCode) { root.lidAwake = exitCode === 0 }
  }

  Process {
    id: switchProc
    onExited: root.refresh()
  }

  // Picks up changes made outside the widget, like `systemctl --user stop`.
  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
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
