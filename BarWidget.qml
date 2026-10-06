import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
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
  property double followerStartedAt: 0
  property int followerRetryDelay: 5000

  // Below this charge, while discharging, Lid Awake turns itself off so a
  // closed laptop is not run flat.
  readonly property int batteryFloor: 10
  readonly property var battery: UPower.displayDevice
  readonly property int batteryLevel: battery && battery.isPresent ? Math.round(battery.percentage * 100) : -1
  readonly property bool discharging: !!(battery && battery.isPresent && UPower.onBattery
    && battery.state === UPowerDeviceState.Discharging)
  readonly property bool belowFloor: batteryLevel >= 0 && discharging && batteryLevel <= batteryFloor
  property bool floorReached: false

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

  function checkBatteryFloor() {
    if (root.belowFloor && root.lidAwake && !floorProc.running) floorProc.running = true
  }

  onLidAwakeChanged: checkBatteryFloor()
  onBelowFloorChanged: {
    if (!root.belowFloor) root.floorReached = false
    checkBatteryFloor()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()

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

  // The unit can fail, restart, or stop outside this copy of the widget: from
  // another bar's copy, or with `systemctl --user stop`. Its journal logs every
  // change, so follow it rather than poll: lines wait in the pipe while the
  // shell is busy, so none is missed. pdeathsig stops the follower if the shell
  // dies without cleaning up.
  Process {
    id: unitFollower
    running: true
    command: ["setpriv", "--pdeathsig", "TERM", "journalctl", "--user", "--follow", "--lines=0", "--output=cat", "--unit=" + root.unitName]
    stdout: SplitParser {
      onRead: root.refresh()
    }
    // Entries logged before the follower started are not replayed, so check
    // the unit once it is following, at startup and after a restart alike.
    onStarted: {
      root.followerStartedAt = Date.now()
      root.refresh()
    }
    // Restart a follower that exits, backing off while it keeps exiting
    // straight away, as one that cannot read the journal would, so a lasting
    // failure retries every few minutes instead of polling. A follower that
    // ran for a minute was working, so the next restart is quick again.
    onExited: {
      var ran = Date.now() - root.followerStartedAt
      root.followerRetryDelay = ran > 60000 ? 5000 : Math.min(root.followerRetryDelay * 2, 300000)
      followerRestart.interval = root.followerRetryDelay
      followerRestart.start()
    }
  }

  Timer {
    id: followerRestart
    onTriggered: unitFollower.running = true
  }

  // Every bar has its own copy of this widget, so the lock lets exactly one of
  // them stop the unit and raise the alarm. Exit 3 means another copy already
  // did. A closed lid hides the toast, so the stop is audible too.
  Process {
    id: floorProc
    command: ["bash", "-c", `
      exec 9>"$XDG_RUNTIME_DIR/lid-awake-floor.lock"
      flock -n 9 || exit 3
      systemctl --user --quiet is-active "$1" || exit 3
      systemctl --user stop "$1" || exit 1
      omarchy-notification-send -g 󰌢 -u critical -i battery-caution -t 30000 \\
        "Lid Awake paused" "Battery reached $2%. Lid-close suspend is enabled again." || true
      pw-play /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga || true
    `, "lid-awake-floor", root.unitName, String(root.batteryFloor)]
    onExited: function(exitCode) {
      if (exitCode === 0 || exitCode === 3) root.floorReached = true
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
    tooltipText: root.lidAwake ? "Allow Lid-Close Suspend"
      : root.floorReached ? "Battery floor reached" : "Stay On With Lid Closed"
    onPressed: root.toggle()
  }
}
