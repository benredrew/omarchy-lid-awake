# Lid Awake

An [Omarchy](https://omarchy.org/) bar widget that keeps a laptop running with
the lid closed. Click it to turn it on or off.

| Off | On |
|-----|----|
| ![Lid Awake off: the laptop icon dimmed on the bar](docs/off.png) | ![Lid Awake on: the laptop icon lit on the bar](docs/on.png) |

Normally, closing the lid suspends the laptop and everything on it stops.
With Lid Awake on, closing the lid still locks the session and turns the
screen off, but the machine keeps running. Downloads, builds, SSH sessions
and remote agent sessions carry on, and Wi-Fi stays connected.

It's for times like these:

- Leaving a long job running and closing the lid to carry the laptop to
  another room.
- Reaching the laptop over SSH, or a remote coding session, with the lid shut.
- Keeping a cat off the keyboard. A remote session keeps working while the
  laptop sits closed, so the cat can't walk across the keys and type into it.
- Keeping a laptop on the desk as a small server without a monitor attached.

With an external monitor connected, Omarchy already keeps the laptop running
when you close the lid (clamshell mode). Lid Awake is for when nothing is
plugged in.

## How it differs from Stay Awake

Omarchy's own Stay Awake (the coffee cup) covers the lid-open case: it keeps
the screen on and unlocked when you stop using the laptop. Lid Awake covers
the lid-closed case. The two don't overlap, and you can turn on both.

## Install

```bash
omarchy plugin add https://github.com/benredrew/omarchy-lid-awake --enable
```

The icon goes in the right-hand section of the bar. It's dimmed while off
and lit while on.

## How it works

Turning it on starts a user unit, `lid-awake`, that holds a systemd-logind
`handle-lid-switch` inhibitor. While the inhibitor is held, logind ignores the
lid. Turning it off stops the unit and releases the inhibitor.

- **No root needed.** Logind lets a logged-in user block the lid switch
  without a password, so the plugin never touches system files.
- **It resets on reboot.** A laptop can't be left stuck awake in a bag
  forever by accident.
- **It turns itself off at 10% battery.** While running on battery, Lid Awake
  switches off when the charge reaches 10%, so normal lid-close suspend comes
  back before the battery is flat. It shows a notification and plays an alarm,
  since the lid may be closed, and the icon's tooltip says why it went off.
  Turning it back on below 10% switches it straight off again.
- **It recovers on its own.** If something kills the unit's helper process,
  systemd restarts it a second later and the lid is held again.
- **It works from a terminal too.** The icon follows the unit's journal, so it
  updates the moment the unit starts or stops, however that happens:

  ```bash
  systemctl --user stop lid-awake        # turn it off
  systemctl --user is-active lid-awake   # check it
  ```

## Things to know

- A closed laptop that's still running can get warm. Don't leave it in a bag
  while it's working hard.
- Plug in for long sessions. On battery, it only runs down to 10%.

## Built into Omarchy

[omacom/omarchy#14273](https://github.com/omacom/omarchy/pull/14273) proposes
Lid Awake as a built-in feature: an indicator next to Stay Awake, an
`omarchy toggle lid awake` command, a menu entry, and a battery floor you can
change in `shell.json`. If it's merged, remove this plugin and use that
instead.

## License

MIT
